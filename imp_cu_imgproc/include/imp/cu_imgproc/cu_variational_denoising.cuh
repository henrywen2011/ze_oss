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
#pragma once

#include <memory>
#include <cuda_runtime_api.h>
#include <imp/core/image_base.hpp>
#include <imp/cu_core/cu_image_gpu.cuh>
#include <imp/cu_core/cu_utils.hpp>
#include <ze/common/macros.hpp>

namespace ze {
namespace cu {

// forward declarations
class Texture2D;

struct VariationalDenoisingParams
{
  float lambda = 10.f;
  std::uint16_t max_iter = 100;
  std::uint16_t primal_dual_energy_check_iter = 0;
  double primal_dual_gap_tolerance = 0.0;
};

/**
 * @brief The VariationalDenoising class
 */
class VariationalDenoising
{
public:
  ZE_POINTER_TYPEDEFS(VariationalDenoising);
  typedef ze::cu::Fragmentation<16> Fragmentation;
  typedef std::shared_ptr<Fragmentation> FragmentationPtr;

public:
  VariationalDenoising();
  virtual ~VariationalDenoising();

  virtual void  __host__  denoise(const ze::ImageBase::Ptr& dst,
                                  const ze::ImageBase::Ptr& src) = 0;

  inline dim3 dimGrid() {return fragmentation_->dimGrid;}
  inline dim3 dimBlock() {return fragmentation_->dimBlock;}
  virtual inline VariationalDenoisingParams& params() { return params_; }


  friend std::ostream& operator<<(std::ostream& os,
                                  const VariationalDenoising& rhs);

protected:
  virtual void init(const Size2u& size);
  inline virtual void print(std::ostream& os) const
  {
    //os << "  size: " << this->size_ << std::endl
    os << "  lambda: " << this->params_.lambda << std::endl
       << "  max_iter: " << this->params_.max_iter << std::endl
       << "  primal_dual_energy_check_iter: " << this->params_.primal_dual_energy_check_iter << std::endl
       << "  primal_dual_gap_tolerance: " << this->params_.primal_dual_gap_tolerance << std::endl
       << std::endl;
  }


  ze::cu::ImageGpu32fC1::Ptr u_;
  ze::cu::ImageGpu32fC1::Ptr u_prev_;
  ze::cu::ImageGpu32fC2::Ptr p_;

  // cuda textures
  std::shared_ptr<ze::cu::Texture2D> f_tex_;
  std::shared_ptr<ze::cu::Texture2D> u_tex_;
  std::shared_ptr<ze::cu::Texture2D> u_prev_tex_;
  std::shared_ptr<ze::cu::Texture2D> p_tex_;

  Size2u size_;
  FragmentationPtr fragmentation_;

  // algorithm parameters
  VariationalDenoisingParams params_;
};

inline std::ostream& operator<<(std::ostream& os,
                                const VariationalDenoising& rhs)
{
  rhs.print(os);
  return os;
}


} // namespace cu
} // namespace ze
