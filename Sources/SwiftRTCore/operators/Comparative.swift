//******************************************************************************
// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Numerics

//==============================================================================
/// and
extension Tensor where TensorElement.Value == Bool {
  /// Computes `lhs .&& rhs` element-wise and returns a tensor of Bool values
  @inlinable public static func .&& (_ lhs: Self, _ rhs: Self) -> Self {
    assert(lhs.shape == rhs.shape, _messageTensorShapeMismatch)
    var result = Tensor(like: lhs)
    currentQueue.and(lhs, rhs, &result)
    return result
  }
}

//==============================================================================
/// or
extension Tensor where TensorElement.Value == Bool {
  /// Computes `lhs .|| rhs` element-wise and returns a tensor of Bool values
  @inlinable public static func .|| (_ lhs: Self, _ rhs: Self) -> Self {
    assert(lhs.shape == rhs.shape, _messageTensorShapeMismatch)
    var result = Tensor(like: lhs)
    currentQueue.or(lhs, rhs, &result)
    return result
  }
}

//==============================================================================
/// min
/// Computes the element-wise minimum of two tensors
/// - Parameter lhs: left hand tensor
/// - Parameter rhs: right hand tensor
/// - Returns: result
@inlinable public func min<S, E>(
  _ lhs: Tensor<S, E>,
  _ rhs: Tensor<S, E>
) -> Tensor<S, E> where E.Value: Comparable {
  assert(lhs.shape == rhs.shape, _messageTensorShapeMismatch)
  var result = Tensor(like: lhs)
  currentQueue.min(lhs, rhs, &result)
  return result
}

// tensor Element
@inlinable public func min<S, E>(
  _ lhs: Tensor<S, E>,
  _ rhs: E.Value
) -> Tensor<S, E> where E.Value: Comparable {
  var result = Tensor(like: lhs)
  currentQueue.min(lhs, rhs, &result)
  return result
}

@inlinable public func min<S, E>(
  _ lhs: Tensor<S, E>,
  _ rhs: Int
) -> Tensor<S, E> where E.Value: Comparable & Numeric {
  min(lhs, E.Value(exactly: rhs)!)
}

// Element tensor
@inlinable public func min<S, E>(
  _ lhs: E.Value,
  _ rhs: Tensor<S, E>
) -> Tensor<S, E> where E.Value: Comparable {
  min(rhs, lhs)
}

// These are added to disambiguate from Swift max when writing
// a TensorView extension
extension Tensor where TensorElement.Value: Comparable {
  @inlinable public func min(_ lhs: Self, _ rhs: Self) -> Self {
    SwiftRTCore.min(lhs, rhs)
  }

  @inlinable public func min(_ lhs: Self, _ rhs: TensorElement.Value) -> Self {
    SwiftRTCore.min(lhs, rhs)
  }

  @inlinable public func min(_ lhs: TensorElement.Value, _ rhs: Self) -> Self {
    SwiftRTCore.min(lhs, rhs)
  }
}

//==============================================================================
/// max
/// Computes the element-wise maximum of two tensors
/// - Parameter lhs: left hand tensor
/// - Parameter rhs: right hand tensor
/// - Returns: result

// tensor tensor
@inlinable public func max<S, E>(
  _ lhs: Tensor<S, E>,
  _ rhs: Tensor<S, E>
) -> Tensor<S, E> where E.Value: Comparable {
  assert(lhs.shape == rhs.shape, _messageTensorShapeMismatch)
  var result = Tensor(like: lhs)
  currentQueue.max(lhs, rhs, &result)
  return result
}

// tensor Element
@inlinable public func max<S, E>(
  _ lhs: Tensor<S, E>,
  _ rhs: E.Value
) -> Tensor<S, E> where E.Value: Comparable {
  var result = Tensor(like: lhs)
  currentQueue.max(lhs, rhs, &result)
  return result
}

@inlinable public func max<S, E>(
  _ lhs: Tensor<S, E>,
  _ rhs: Int
) -> Tensor<S, E> where E.Value: Comparable & Numeric {
  max(lhs, E.Value(exactly: rhs)!)
}

// Element tensor
// delegate to reverse
@inlinable public func max<S, E>(
  _ lhs: E.Value,
  _ rhs: Tensor<S, E>
) -> Tensor<S, E> where E.Value: Comparable {
  max(rhs, lhs)
}

// These are added to disambiguate from Swift max when writing
// a TensorView extension
extension Tensor where TensorElement.Value: Comparable {
  @inlinable public func max(_ lhs: Self, _ rhs: Self) -> Self {
    SwiftRTCore.max(lhs, rhs)
  }

  @inlinable public func max(_ lhs: Self, _ rhs: TensorElement.Value) -> Self {
    SwiftRTCore.max(lhs, rhs)
  }

  @inlinable public func max(_ lhs: TensorElement.Value, _ rhs: Self) -> Self {
    SwiftRTCore.max(lhs, rhs)
  }
}

//==============================================================================
/// equal
extension Tensor: Equatable where TensorElement.Value: Equatable {
  /// Performs element-wise equality comparison and returns a tensor of Bool values
  @inlinable public static func .== (
    _ lhs: Self,
    _ rhs: Self
  ) -> Tensor<Shape, Bool> {
    assert(lhs.shape == rhs.shape, _messageTensorShapeMismatch)
    var result = Tensor<Shape, Bool>(shape: lhs.shape, order: lhs.order)
    currentQueue.equal(lhs, rhs, &result)
    return result
  }

  /// Performs element-wise equality comparison and returns a tensor of Bool values
  @inlinable public static func .== (
    _ lhs: Self,
    _ rhs: Element
  ) -> Tensor<Shape, Bool> {
    var out = Tensor<Shape, Bool>(shape: lhs.shape, order: lhs.order)
    currentQueue.equal(lhs, rhs, &out)
    return out
  }

  /// - Parameter lhs: left hand tensor
  /// - Parameter rhs: right hand tensor
  /// - Returns: `true` if the tensors are equal
  @inlinable public static func == (lhs: Self, rhs: Self) -> Bool {
    // the bounds must match or they are not equal
    guard lhs.shape == rhs.shape else { return false }

    // if lhs is an alias for rhs, then they match
    if lhs.storage === rhs.storage && lhs.storageBase == rhs.storageBase {
      return true
    }

    // compare elements
    return (lhs .== rhs).all().element
  }
}

//==============================================================================
/// elementsAlmostEqual
/// Performs element-wise equality comparison within the tolerance range
/// and returns a tensor of Bool values
@inlinable public func elementsAlmostEqual<S, E>(
  _ lhs: Tensor<S, E>,
  _ rhs: Tensor<S, E>,
  tolerance: E.Value
) -> Tensor<S, Bool> where E.Value: SignedNumeric & Comparable {
  assert(lhs.shape == rhs.shape, _messageTensorShapeMismatch)
  var result = Tensor<S, Bool>(shape: lhs.shape, order: lhs.order)
  currentQueue.elementsAlmostEqual(lhs, rhs, tolerance, &result)
  return result
}

extension Tensor where TensorElement.Value: SignedNumeric & Comparable {
  @inlinable public func elementsAlmostEqual(
    _ rhs: Self,
    tolerance: TensorElement.Value
  ) -> Tensor<Shape, Bool> {
    SwiftRTCore.elementsAlmostEqual(self, rhs, tolerance: tolerance)
  }
}

@inlinable public func almostEqual<S, E>(
  _ lhs: Tensor<S, E>,
  _ rhs: Tensor<S, E>,
  tolerance: E.Value
) -> Bool where E.Value: SignedNumeric & Comparable {
  elementsAlmostEqual(lhs, rhs, tolerance: tolerance).all().element
}

//==============================================================================
/// notEqual
/// Computes `lhs != rhs` element-wise and returns a `TensorView` of Boolean
/// values.
extension Tensor where TensorElement.Value: Equatable {
  @inlinable public static func .!= (_ lhs: Self, _ rhs: Self) -> Tensor<Shape, Bool> {
    assert(lhs.shape == rhs.shape, _messageTensorShapeMismatch)
    var result = Tensor<Shape, Bool>(shape: lhs.shape, order: lhs.order)
    currentQueue.notEqual(lhs, rhs, &result)
    return result
  }
}

//==============================================================================
/// greater
/// Computes `lhs .> rhs` element-wise and returns a tensor of Bool values
extension Tensor where TensorElement.Value: Comparable {
  @inlinable public static func .> (_ lhs: Self, _ rhs: Self) -> Tensor<Shape, Bool> {
    assert(lhs.shape == rhs.shape, _messageTensorShapeMismatch)
    var result = Tensor<Shape, Bool>(shape: lhs.shape, order: lhs.order)
    currentQueue.greater(lhs, rhs, &result)
    return result
  }

  @inlinable public static func .> (_ lhs: Self, _ rhs: Element) -> Tensor<Shape, Bool> {
    var result = Tensor<Shape, Bool>(shape: lhs.shape, order: lhs.order)
    currentQueue.greater(lhs, rhs, &result)
    return result
  }
}

@inlinable public func .> <S, E>(_ lhs: Tensor<S, Complex<E>>, _ rhs: E) -> Tensor<S, Bool> {
  lhs .> Complex<E>(rhs)
}

//==============================================================================
/// greaterOrEqual
extension Tensor where TensorElement.Value: Comparable {
  /// Computes `lhs .>= rhs` element-wise and returns a tensor of Bool values
  @inlinable public static func .>= (_ lhs: Self, _ rhs: Self) -> Tensor<Shape, Bool> {
    assert(lhs.shape == rhs.shape, _messageTensorShapeMismatch)
    var result = Tensor<Shape, Bool>(shape: lhs.shape, order: lhs.order)
    currentQueue.greaterOrEqual(lhs, rhs, &result)
    return result
  }

  @inlinable public static func .>= (_ lhs: Self, _ rhs: Element) -> Tensor<Shape, Bool> {
    var result = Tensor<Shape, Bool>(shape: lhs.shape, order: lhs.order)
    currentQueue.greaterOrEqual(lhs, rhs, &result)
    return result
  }
}

//==============================================================================
/// less
extension Tensor where TensorElement.Value: Comparable {
  /// Computes `lhs .< rhs` element-wise and returns a tensor of Bool values
  @inlinable public static func .< (_ lhs: Self, _ rhs: Self) -> Tensor<Shape, Bool> {
    assert(lhs.shape == rhs.shape, _messageTensorShapeMismatch)
    var result = Tensor<Shape, Bool>(shape: lhs.shape, order: lhs.order)
    currentQueue.less(lhs, rhs, &result)
    return result
  }

  @inlinable public static func .< (_ lhs: Self, _ rhs: Element) -> Tensor<Shape, Bool> {
    var result = Tensor<Shape, Bool>(shape: lhs.shape, order: lhs.order)
    currentQueue.less(lhs, rhs, &result)
    return result
  }
}

//==============================================================================
/// lessOrEqual
extension Tensor where TensorElement.Value: Comparable {
  /// Computes `lhs .<= rhs` element-wise and returns a tensor of Bool values
  @inlinable public static func .<= (_ lhs: Self, _ rhs: Self) -> Tensor<Shape, Bool> {
    assert(lhs.shape == rhs.shape, _messageTensorShapeMismatch)
    var result = Tensor<Shape, Bool>(shape: lhs.shape, order: lhs.order)
    currentQueue.lessOrEqual(lhs, rhs, &result)
    return result
  }

  @inlinable public static func .<= (_ lhs: Self, _ rhs: Element) -> Tensor<Shape, Bool> {
    var result = Tensor<Shape, Bool>(shape: lhs.shape, order: lhs.order)
    currentQueue.lessOrEqual(lhs, rhs, &result)
    return result
  }
}
