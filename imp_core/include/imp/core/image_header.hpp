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

#include <ze/common/logging.hpp>
#include <ze/common/types.hpp>
#include <imp/core/pixel_enums.hpp>
#include <imp/core/roi.hpp>
#include <imp/core/size.hpp>
#include <imp/core/types.hpp>

namespace ze {

//! Defines an image header including all size information. No data included.
struct ImageHeader
{
  PixelType pixel_type{PixelType::undefined};
  uint8_t pixel_size{0}; //!< Pixel size in bytes.
  PixelOrder pixel_order{PixelOrder::undefined};
  Size2u size{0, 0};
  Roi2u roi{0, 0, 0, 0}; //!< Region of interest. x,y offset and width, height.
  uint32_t pitch{0}; //!< Row alignment in bytes.
  MemoryType memory_type{MemoryType::Undefined}; //!< Memory Type.

  ImageHeader() = default;
  ~ImageHeader() = default;

  ImageHeader(
      PixelType _pixel_type,
      uint8_t _pixel_size = 0,
      PixelOrder _pixel_order = PixelOrder::undefined,
      Size2u _size = Size2u{0,0},
      Roi2u _roi = Roi2u{0,0,0,0},
      uint32_t _pitch = 0,
      MemoryType _memory_type = MemoryType::Undefined)
    : pixel_type(_pixel_type)
    , pixel_size(_pixel_size)
    , pixel_order(_pixel_order)
    , size(_size)
    , roi((_roi != Roi2u{0,0,0,0})? _roi : Roi2u(size))
    , pitch(_pitch)
    , memory_type(_memory_type)
  { ; }

  bool isGpuMemory() const
  {
    switch (memory_type)
    {
    case MemoryType::Cpu:
    case MemoryType::CpuAligned:
      return false;
    case MemoryType::Gpu:
    case MemoryType::GpuAligned:
    case MemoryType::Managed:
    case MemoryType::ManagedAligned:
    case MemoryType::Unified:
    case MemoryType::UnifiedAligned:
      return true;
    default:
      CHECK(false) << "Undefined or unitialized memory";
      return false;
    }
  }

  bool hasRoi() const
  {
    return ((roi != Roi2u{0,0,0,0}) && (roi != Roi2u(size)));
  }
};


} // namespace ze
