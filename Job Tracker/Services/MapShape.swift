//
//  MapShape.swift
//  Job Tracker
//
//  Updated by Assistant on 8/23/25
//

import Foundation
import MapKit
import SwiftUI
import UIKit

// MARK: - Codable helpers
/// Codable representation of a UIColor as sRGB components.
private struct RGBAColor: Codable, Equatable {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat

    init(_ color: UIColor) {
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
        let c = color.resolvedColor(with: .current)
        c.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
        self.r = rr; self.g = gg; self.b = bb; self.a = aa
    }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: a) }
}

private struct _Coord: Codable, Equatable { let lat: Double; let lng: Double }
private extension CLLocationCoordinate2D {
    init(_ c: _Coord) { self.init(latitude: c.lat, longitude: c.lng) }
    var codable: _Coord { _Coord(lat: latitude, lng: longitude) }
}

// MARK: - ShapeStyle
public struct ShapeStyle: Equatable, Codable {
    public var color: UIColor
    public var width: CGFloat
    public var dashed: Bool

    // Arrow options (used for polylines)
    public var arrow: Bool
    public var arrowSize: CGFloat
    public var arrowLength: CGFloat

    public init(
        color: UIColor = .systemOrange,
        width: CGFloat = 4,
        dashed: Bool = false,
        arrow: Bool = false,
        arrowSize: CGFloat = 12,
        arrowLength: CGFloat = 20
    ) {
        self.color = color
        self.width = width
        self.dashed = dashed
        self.arrow = arrow
        self.arrowSize = arrowSize
        self.arrowLength = arrowLength
    }

    public static var `default`: ShapeStyle { ShapeStyle() }

    // MARK: Codable
    private enum CodingKeys: String, CodingKey { case color, width, dashed, arrow, arrowSize, arrowLength }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rgba = try c.decode(RGBAColor.self, forKey: .color)
        self.color = rgba.uiColor
        self.width = try c.decode(CGFloat.self, forKey: .width)
        self.dashed = try c.decode(Bool.self, forKey: .dashed)
        self.arrow = try c.decode(Bool.self, forKey: .arrow)
        self.arrowSize = try c.decode(CGFloat.self, forKey: .arrowSize)
        self.arrowLength = try c.decode(CGFloat.self, forKey: .arrowLength)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(RGBAColor(color), forKey: .color)
        try c.encode(width, forKey: .width)
        try c.encode(dashed, forKey: .dashed)
        try c.encode(arrow, forKey: .arrow)
        try c.encode(arrowSize, forKey: .arrowSize)
        try c.encode(arrowLength, forKey: .arrowLength)
    }
}

// MARK: - MapShape
public struct MapShape: Identifiable, Equatable, Hashable, Codable {
    public var id: UUID
    public var kind: Kind
    public var style: ShapeStyle

    public init(id: UUID = UUID(), kind: Kind, style: ShapeStyle = .default) {
        self.id = id
        self.kind = kind
        self.style = style
    }

    // Hash/Equality by id only (bindings remain stable even if geometry changes)
    public static func == (lhs: MapShape, rhs: MapShape) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: Kind
    public enum Kind: Equatable {
        case polyline([CLLocationCoordinate2D])
        case polygon([CLLocationCoordinate2D])
        case circle(center: CLLocationCoordinate2D, radius: CLLocationDistance)
        case label(coord: CLLocationCoordinate2D, text: String)

        public static func == (lhs: Kind, rhs: Kind) -> Bool {
            switch (lhs, rhs) {
            case let (.polyline(a), .polyline(b)):
                return Self.coordsEqual(a, b)
            case let (.polygon(a), .polygon(b)):
                return Self.coordsEqual(a, b)
            case let (.circle(c1, r1), .circle(c2, r2)):
                return Self.coordEqual(c1, c2) && r1 == r2
            case let (.label(c1, t1), .label(c2, t2)):
                return Self.coordEqual(c1, c2) && t1 == t2
            default:
                return false
            }
        }

        private static func coordsEqual(_ a: [CLLocationCoordinate2D], _ b: [CLLocationCoordinate2D]) -> Bool {
            guard a.count == b.count else { return false }
            for i in 0..<a.count where !coordEqual(a[i], b[i]) { return false }
            return true
        }

        private static func coordEqual(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
            a.latitude == b.latitude && a.longitude == b.longitude
        }
    }

    // MARK: Codable
    private enum CodingKeys: String, CodingKey { case id, kind, style }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.style = try c.decode(ShapeStyle.self, forKey: .style)
        self.kind = try Kind(from: c.superDecoder(forKey: .kind))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(style, forKey: .style)
        try kind.encode(to: c.superEncoder(forKey: .kind))
    }
}

// MARK: - Codable for MapShape.Kind
extension MapShape.Kind: Codable {
    private enum KindKey: String, CodingKey { case type, polyline, polygon, center, radius, label, text }
    private enum KindType: String, Codable { case polyline, polygon, circle, label }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: KindKey.self)
        let t = try c.decode(KindType.self, forKey: .type)
        switch t {
        case .polyline:
            let pts = try c.decode([_Coord].self, forKey: .polyline).map { CLLocationCoordinate2D($0) }
            self = .polyline(pts)
        case .polygon:
            let pts = try c.decode([_Coord].self, forKey: .polygon).map { CLLocationCoordinate2D($0) }
            self = .polygon(pts)
        case .circle:
            let center = try c.decode(_Coord.self, forKey: .center)
            let radius = try c.decode(CLLocationDistance.self, forKey: .radius)
            self = .circle(center: CLLocationCoordinate2D(center), radius: radius)
        case .label:
            let coord = try c.decode(_Coord.self, forKey: .label)
            let text = try c.decode(String.self, forKey: .text)
            self = .label(coord: CLLocationCoordinate2D(coord), text: text)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: KindKey.self)
        switch self {
        case .polyline(let pts):
            try c.encode(KindType.polyline, forKey: .type)
            try c.encode(pts.map { $0.codable }, forKey: .polyline)
        case .polygon(let pts):
            try c.encode(KindType.polygon, forKey: .type)
            try c.encode(pts.map { $0.codable }, forKey: .polygon)
        case .circle(let center, let radius):
            try c.encode(KindType.circle, forKey: .type)
            try c.encode(center.codable, forKey: .center)
            try c.encode(radius, forKey: .radius)
        case .label(let coord, let text):
            try c.encode(KindType.label, forKey: .type)
            try c.encode(coord.codable, forKey: .label)
            try c.encode(text, forKey: .text)
        }
    }
}

// MARK: - Convenience
public extension MapShape {
    static func line(_ points: [CLLocationCoordinate2D], style: ShapeStyle = .default) -> MapShape {
        MapShape(kind: .polyline(points), style: style)
    }
    static func polygon(_ points: [CLLocationCoordinate2D], style: ShapeStyle = .default) -> MapShape {
        MapShape(kind: .polygon(points), style: style)
    }
    static func circle(center: CLLocationCoordinate2D, radius: CLLocationDistance, style: ShapeStyle = .default) -> MapShape {
        MapShape(kind: .circle(center: center, radius: radius), style: style)
    }
    static func label(at coord: CLLocationCoordinate2D, text: String, style: ShapeStyle = .default) -> MapShape {
        MapShape(kind: .label(coord: coord, text: text), style: style)
    }
}

// MARK: - SwiftUI Color helpers
public extension Color {
    init(uiColor: UIColor) { self = Color(uiColor) }
}
