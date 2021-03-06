// Copyright (c) 2015-2016, ETH Zurich, Wyss Zurich, Zurich Eye
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the ETH Zurich, Wyss Zurich, Zurich Eye nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL ETH Zurich, Wyss Zurich, Zurich Eye BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#include <imp/cu_imgproc/cu_rof_denoising.cuh>

#include <iostream>

#include <cuda_runtime.h>

#include <imp/cuda_toolkit/helper_math.hpp>
#include <imp/core/pixel.hpp>
#include <imp/cu_core/cu_texture.cuh>
#include <imp/cu_core/cu_k_derivative.cuh>
#include <imp/cu_core/cu_math.cuh>
#include <ze/common/logging.hpp>


namespace ze {
namespace cu {

//-----------------------------------------------------------------------------
__global__ void k_initRofSolver(Pixel32fC1* d_u, Pixel32fC1* d_u_prev,
                                size_t stride_u,
                                Pixel32fC2* d_p, size_t stride_p,
                                ze::cu::Texture2D f_tex,
                                size_t width, size_t height)
{
  int x = blockIdx.x*blockDim.x + threadIdx.x;
  int y = blockIdx.y*blockDim.y + threadIdx.y;

  if (x<width && y<height)
  {
    float val = tex2DFetch<float>(f_tex, x, y);
    d_u[y*stride_u + x] = val;
    d_u_prev[y*stride_u + x] = val;
    d_p[y*stride_p + x] = Pixel32fC2(0.0f, 0.0f);
  }
}

//-----------------------------------------------------------------------------
__global__ void k_rofPrimalUpdate(
    Pixel32fC1* d_u, Pixel32fC1* d_u_prev, size_t stride_u,
    Texture2D f_tex, Texture2D u_tex, Texture2D p_tex,
    float lambda, float tau, float theta, size_t width, size_t height)
{
  int x = blockIdx.x*blockDim.x + threadIdx.x;
  int y = blockIdx.y*blockDim.y + threadIdx.y;

  if (x<width && y<height)
  {
    float f = tex2DFetch<float>(f_tex, x, y);
    float u = tex2DFetch<float>(u_tex, x, y);
    float u_prev = u;
    float div = dpAd(p_tex, x, y, width, height);

    u = (u + tau*(div + lambda*f)) / (1.0f + tau*lambda);

    d_u[y*stride_u + x] = u;
    d_u_prev[y*stride_u + x] = u + theta*(u-u_prev);
  }
}

//-----------------------------------------------------------------------------
__global__ void k_rofDualUpdate(
    Pixel32fC2* d_p, size_t stride_p, Texture2D p_tex, Texture2D u_prev_tex,
    float sigma, size_t width, size_t height)
{
  int x = blockIdx.x*blockDim.x + threadIdx.x;
  int y = blockIdx.y*blockDim.y + threadIdx.y;

  if (x<width && y<height)
  {
    float2 p = tex2DFetch<float2>(p_tex, x, y);
    float2 dp_u = dp(u_prev_tex, x, y);

    p = p + sigma*dp_u;
    p = p / max(1.0f, length(p));
    d_p[y*stride_p + x] = {p.x, p.y};
  }
}

//-----------------------------------------------------------------------------
__global__ void k_convertResult8uC1(Pixel8uC1* d_u, size_t stride_u,
                                    ze::cu::Texture2D u_tex,
                                    size_t width, size_t height)
{
  int x = blockIdx.x*blockDim.x + threadIdx.x;
  int y = blockIdx.y*blockDim.y + threadIdx.y;

  if (x<width && y<height)
  {
    d_u[y*stride_u + x] = static_cast<std::uint8_t>(
          255.0f * tex2DFetch<float>(u_tex, x, y));
  }
}

//-----------------------------------------------------------------------------
__global__ void k_rofPrimalEnergy(Pixel32fC1* d_ep,  size_t stride,
                                  uint32_t width, uint32_t height,
                                  float lambda, Texture2D f_tex, Texture2D u_tex)
{
  int x = blockIdx.x*blockDim.x + threadIdx.x;
  int y = blockIdx.y*blockDim.y + threadIdx.y;

  if (x<width && y<height)
  {
    float2 dp_u = dp(u_tex, x, y);
    float f = tex2DFetch<float>(f_tex, x, y);
    float u = tex2DFetch<float>(u_tex, x, y);
    d_ep[y*stride + x] = length(dp_u) + lambda/2.0f * ze::cu::sqr(u-f);
  }
}

//-----------------------------------------------------------------------------
__global__ void k_rofDualEnergy(Pixel32fC1* d_ed,  size_t stride,
                                uint32_t width, uint32_t height,
                                float lambda, Texture2D f_tex, Texture2D p_tex)
{
  int x = blockIdx.x*blockDim.x + threadIdx.x;
  int y = blockIdx.y*blockDim.y + threadIdx.y;

  if (x<width && y<height)
  {
    float f = tex2DFetch<float>(f_tex, x, y);
    float div = dpAd(p_tex, x, y, width, height);
    d_ed[y*stride + x] = -ze::cu::sqr(div)/(2.0f*lambda) - div*f;
  }
}


//#############################################################################

//-----------------------------------------------------------------------------
template<typename Pixel>
void RofDenoising<Pixel>::init(const Size2u& size)
{
  Base::init(size);
  IMP_CUDA_CHECK();

  // setup textures
  // (except input image which is set when f_ is set from the input image)
  u_tex_ = u_->genTexture(false, cudaFilterModeLinear, cudaAddressModeClamp,
                          cudaReadModeElementType);
  u_prev_tex_ = u_prev_->genTexture(false, cudaFilterModeLinear,
                                    cudaAddressModeClamp, cudaReadModeElementType);
  p_tex_ = p_->genTexture(false, cudaFilterModeLinear, cudaAddressModeClamp,
                          cudaReadModeElementType);
  IMP_CUDA_CHECK();

  // init internal vars
  k_initRofSolver
      <<<
        dimGrid(), dimBlock()
      >>> (u_->data(), u_prev_->data(), u_->stride(),
           p_->data(), p_->stride(),
           *f_tex_, size_.width(), size_.height());
  IMP_CUDA_CHECK();
}

//-----------------------------------------------------------------------------
template<typename Pixel>
void RofDenoising<Pixel>::denoise(const std::shared_ptr<ImageBase>& dst,
                                  const std::shared_ptr<ImageBase>& src)
{
  VLOG(100) << "[Solver @gpu] RofDenoising::denoise:";
  CHECK(src);
  CHECK(dst);
  CHECK_EQ(src->size(), dst->size());

  f_ = src->as<ImageGpu>();
  CHECK(f_);
  f_tex_ = f_->genTexture(false, cudaFilterModeLinear, cudaAddressModeClamp,
                          (f_->bitDepth()==8) ? cudaReadModeNormalizedFloat :
                                                cudaReadModeElementType);

  if (size_ != f_->size())
  {
    this->init(f_->size());
  }

  // internal algorithm params
  float L = sqrtf(8.f);
  float tau = 1.f/L;
  float sigma = 1.f/L;
  float theta = 1.f;

  for(int iter = 0; iter < this->params_.max_iter; ++iter)
  {
    if (sigma < 1000.0f)
    {
      theta = 1.f/sqrtf(1.0f + 0.7f * this->params_.lambda * tau);
    }
    else
    {
      theta = 1.0f;
    }

    VLOG(101) << "(rof solver) iter: " << iter << "; tau: " << tau
              << "; sigma: " << sigma << "; theta: " << theta;

    if (params_.primal_dual_energy_check_iter > 0
        && iter % params_.primal_dual_energy_check_iter
        && params_.primal_dual_gap_tolerance > 0.f)
    {
      double primal_energy = 0.0, dual_energy = 0.0;
      this->primalDualEnergy(primal_energy, dual_energy);
      VLOG(102) << "ENERGIES: primal: " << primal_energy <<
                   "; dual: " << dual_energy;
    }

    k_rofDualUpdate
        <<<
          dimGrid(), dimBlock()
        >>> (p_->data(), p_->stride(), *p_tex_, *u_prev_tex_,
             sigma, size_.width(), size_.height());

    k_rofPrimalUpdate
        <<<
          dimGrid(), dimBlock()
        >>> (u_->data(), u_prev_->data(), u_->stride(),
             *f_tex_, *u_tex_, *p_tex_, params_.lambda, tau, theta,
             size_.width(), size_.height());

    sigma /= theta;
    tau *= theta;
  }
  IMP_CUDA_CHECK();

  switch (dst->pixelType())
  {
  case PixelType::i8uC1:
  {
    std::shared_ptr<ImageGpu8uC1> u(std::dynamic_pointer_cast<ImageGpu8uC1>(dst));
    k_convertResult8uC1
        <<<
          dimGrid(), dimBlock()
        >>> (u->data(), u->stride(),
             *u_tex_, size_.width(), size_.height());
  }
    break;
  case PixelType::i32fC1:
  {
    std::shared_ptr<ImageGpu32fC1> u(std::dynamic_pointer_cast<ImageGpu32fC1>(dst));
    u_->copyTo(*u);
  }
    break;
  default:
    LOG(FATAL) << "Unsupported pixel type.";
    break;
  }
  IMP_CUDA_CHECK();
}

//-----------------------------------------------------------------------------
template<typename Pixel>
void RofDenoising<Pixel>::primalDualEnergy(
    double& primal_energy, double& dual_energy)
{
  if (!primal_energies_ || !dual_energies_)
  {
    primal_energies_.reset(new ImageGpu32fC1(size_));
    dual_energies_.reset(new ImageGpu32fC1(size_));
  }

  Pixel32fC1 ep_min, ep_max, ed_min, ed_max;

  k_rofPrimalEnergy
      <<<
        this->dimGrid(), this->dimBlock()
      >>> (primal_energies_->data(), primal_energies_->stride(),
           size_.width(), size_.height(), params_.lambda,
           *f_tex_, *u_tex_);

  // TODO sum
  primal_energy = 10.0;
  ze::cu::minMax(*primal_energies_, ep_min, ep_max);
  IMP_CUDA_CHECK();

  k_rofDualEnergy
      <<<
        this->dimGrid(), this->dimBlock()
      >>> (dual_energies_->data(), dual_energies_->stride(),
           size_.width(), size_.height(), params_.lambda,
           *f_tex_, *p_tex_);
  dual_energy = 20.0;
  ze::cu::minMax(*dual_energies_, ed_min, ed_max);

  IMP_CUDA_CHECK();
}

//-----------------------------------------------------------------------------
template<typename Pixel>
void RofDenoising<Pixel>::print(std::ostream& os) const
{
  os << "ROF Denoising:" << std::endl;
  this->Base::print(os);
}

//=============================================================================
// Explicitely instantiate the desired classes
// (sync with typedefs at the end of the hpp file)
template class RofDenoising<ze::Pixel8uC1>;
template class RofDenoising<ze::Pixel32fC1>;

} // namespace cu
} // namespace ze
