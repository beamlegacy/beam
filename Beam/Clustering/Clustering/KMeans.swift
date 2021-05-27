// Code taken from Swift Algorithm Clum (https://github.com/raywenderlich/swift-algorithm-club).
// Code was copied instead of cloned because of the size of the full repository.

import Foundation

struct Vector: CustomStringConvertible, Equatable {
  private(set) var length = 0
  private(set) var data: [Double]

  init(_ data: [Double]) {
    self.data = data
    self.length = data.count
  }

  var description: String {
    return "Vector (\(data)"
  }

  func distanceTo(_ other: Vector) -> Double {
    var result = 0.0
    for idx in 0..<length {
      result += pow(data[idx] - other.data[idx], 2.0)
    }
    return sqrt(result)
  }
}

func == (left: Vector, right: Vector) -> Bool {
  for idx in 0..<left.length {
    if left.data[idx] != right.data[idx] {
      return false
    }
  }
  return true
}

func + (left: Vector, right: Vector) -> Vector {
  var results = [Double]()
  for idx in 0..<left.length {
    results.append(left.data[idx] + right.data[idx])
  }
  return Vector(results)
}

func += (left: inout Vector, right: Vector) {
  left = left + right
}

func - (left: Vector, right: Vector) -> Vector {
  var results = [Double]()
  for idx in 0..<left.length {
    results.append(left.data[idx] - right.data[idx])
  }
  return Vector(results)
}

func -= (left: inout Vector, right: Vector) {
  left = left - right
}

func / (left: Vector, right: Double) -> Vector {
  var results = [Double](repeating: 0, count: left.length)
  for (idx, value) in left.data.enumerated() {
    results[idx] = value / right
  }
  return Vector(results)
}

func /= (left: inout Vector, right: Double) {
  left = left / right
}


class KMeans<Label: Hashable> {
  let numCenters: Int
  let labels: [Label]
  private(set) var centroids = [Vector]()

  init(labels: [Label]) {
    assert(labels.count > 1, "Exception: KMeans with less than 2 centers.")
    self.labels = labels
    self.numCenters = labels.count
  }

  private func indexOfNearestCenter(_ x: Vector, centers: [Vector]) -> Int {
    var nearestDist = Double.greatestFiniteMagnitude
    var minIndex = 0

    for (idx, center) in centers.enumerated() {
      let dist = x.distanceTo(center)
      if dist < nearestDist {
        minIndex = idx
        nearestDist = dist
      }
    }
    return minIndex
  }

  func trainCenters(_ points: [Vector], convergeDistance: Double) {
    let zeroVector = Vector([Double](repeating: 0, count: points[0].length))

    // Randomly take k objects from the input data to make the initial centroids.
    var centers = reservoirSample(points, k: numCenters)

    var centerMoveDist = 0.0
    repeat {
      // This array keeps track of which data points belong to which centroids.
      var classification: [[Vector]] = .init(repeating: [], count: numCenters)

      // For each data point, find the centroid that it is closest to.
      for p in points {
        let classIndex = indexOfNearestCenter(p, centers: centers)
        classification[classIndex].append(p)
      }

      // Take the average of all the data points that belong to each centroid.
      // This moves the centroid to a new position.
      let newCenters = classification.map { assignedPoints in
        assignedPoints.reduce(zeroVector, +) / Double(assignedPoints.count)
      }

      // Find out how far each centroid moved since the last iteration. If it's
      // only a small distance, then we're done.
      centerMoveDist = 0.0
      for idx in 0..<numCenters {
        centerMoveDist += centers[idx].distanceTo(newCenters[idx])
      }

      centers = newCenters
    } while centerMoveDist > convergeDistance

    centroids = centers
  }

  func fit(_ point: Vector) -> Label {
    assert(!centroids.isEmpty, "Exception: KMeans tried to fit on a non trained model.")

    let centroidIndex = indexOfNearestCenter(point, centers: centroids)
    return labels[centroidIndex]
  }

  func fit(_ points: [Vector]) -> [Label] {
    assert(!centroids.isEmpty, "Exception: KMeans tried to fit on a non trained model.")

    return points.map(fit)
  }
}

// Pick k random elements from samples
func reservoirSample<T>(_ samples: [T], k: Int) -> [T] {
  var result = [T]()

  // Fill the result array with first k elements
  for i in 0..<k {
    result.append(samples[i])
  }

  // Randomly replace elements from remaining pool
  for i in k..<samples.count {
    let j = Int(arc4random_uniform(UInt32(i + 1)))
    if j < k {
      result[j] = samples[i]
    }
  }
  return result
}
