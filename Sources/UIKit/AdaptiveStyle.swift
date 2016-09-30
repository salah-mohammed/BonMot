//
//  AdaptiveStyle.swift
//
//  Created by Brian King on 8/31/16.
//  Copyright © 2016 Raizlabs. All rights reserved.
//

import UIKit

public enum AdaptiveStyle {
    case control
    case body
    case preferred
    case above(size: CGFloat, family: String)
    case below(size: CGFloat, family: String)
}

/// Adaptive styles conform to `StyleAttributeTransformation` to add the 'adaptations'
/// to the StyleAttributes when styled, but the transformation is only triggered once
/// the string or StyleAttributes are adapted to a trait collection.
extension AdaptiveStyle: StyleAttributeTransformation {

    enum AttributeName {

        static let nonAdaptedFont = "BonMotNonAdaptedFont"

    }

    public func style(attributes theAttributes: StyleAttributes) -> StyleAttributes {
        guard let font = theAttributes[NSFontAttributeName] as? BONFont else {
            print("No font to adapt, ignoring adaptive style")
            return theAttributes
        }
        var attributes = theAttributes
        attributes[AttributeName.nonAdaptedFont] = font
        attributes = EmbededTransformationHelpers.embed(transformation: self, to: attributes)
        return attributes
    }

}

extension AdaptiveStyle: AdaptiveStyleTransformation {

    func adapt(attributes theAttributes: StyleAttributes, to traitCollection: UITraitCollection) -> StyleAttributes? {
        guard var font = theAttributes[AttributeName.nonAdaptedFont] as? BONFont else {
            fatalError("The designated font is set when the adaptive style is added")
        }
        let pointSize = font.pointSize
        let contentSizeCategory = traitCollection.bon_preferredContentSizeCategory
        var styleAttributes = theAttributes
        switch self {
        case .control:
            font = UIFont(descriptor: font.fontDescriptor, size: AdaptiveStyle.adapt(designatedSize: pointSize, for: contentSizeCategory))
        case .body:
            font = UIFont(descriptor: font.fontDescriptor, size: AdaptiveStyle.adaptBody(designatedSize: pointSize, for: contentSizeCategory))
        case .preferred:
            if let textStyle = font.textStyle {
                font = UIFont.bon_preferredFont(forTextStyle: textStyle, compatibleWith: traitCollection)
            }
            else {
                print("No text style in the font, can not adapt")
            }
        case .above(let size, let family):
            font = pointSize > size ? font.font(familyName: family) : font
        case .below(let size, let family):
            font = pointSize < size ? font.font(familyName: family) : font
        }
        styleAttributes[NSFontAttributeName] = font
        return styleAttributes
    }

}

extension AdaptiveStyle: EmbededTransformation {

    struct Key {

        static let family = "family"

    }

    struct Value {

        static let control = "control"
        static let body = "body"
        static let preferred = "preferred"
        static let above = "above"
        static let below = "below"

    }

    var representation: StyleAttributes {
        switch self {
        case let .above(size, family):
            return [
                EmbededTransformationHelpers.Key.type: Value.above,
                EmbededTransformationHelpers.Key.size: size,
                Key.family: family,
            ]
        case let .below(size, family):
            return [
                EmbededTransformationHelpers.Key.type: Value.below,
                EmbededTransformationHelpers.Key.size: size,
                Key.family: family,
            ]
        case .control:
            return [EmbededTransformationHelpers.Key.type: Value.control]
        case .body:
            return [EmbededTransformationHelpers.Key.type: Value.body]
        case .preferred:
            return [EmbededTransformationHelpers.Key.type: Value.preferred]
        }
    }

    static func from(representation dictionary: [String: StyleAttributeValue]) -> EmbededTransformation? {
        switch (dictionary[EmbededTransformationHelpers.Key.type] as? String,
                dictionary[EmbededTransformationHelpers.Key.size] as? CGFloat,
                dictionary[Key.family] as? String) {
        case (Value.control?, nil, nil):
            return AdaptiveStyle.control
        case (Value.body?, nil, nil):
            return AdaptiveStyle.body
        case (Value.preferred?, nil, nil):
            return AdaptiveStyle.preferred
        case let (Value.above?, size?, family?):
            return AdaptiveStyle.above(size: size, family: family)
        case let (Value.below?, size?, family?):
            return AdaptiveStyle.below(size: size, family: family)
        default:
            return nil
        }
    }

}

extension AdaptiveStyle {
    /// An internal lookup table defining the font shift to use for each content size category
    static var shiftTable: [BonMotContentSizeCategory: CGFloat] {
        #if swift(>=3.0)
            return [
                .extraSmall: -3,
                .small: -2,
                .medium: -1,
                .large: 0,
                .extraLarge: 2,
                .extraExtraLarge: 4,
                .extraExtraExtraLarge: 6,
                .accessibilityMedium: 11,
                .accessibilityLarge: 16,
                .accessibilityExtraLarge: 23,
                .accessibilityExtraExtraLarge: 30,
                .accessibilityExtraExtraExtraLarge: 36,
            ]
        #else
            return [
                UIContentSizeCategoryExtraSmall: -3,
                UIContentSizeCategorySmall: -2,
                UIContentSizeCategoryMedium: -1,
                UIContentSizeCategoryLarge: 0,
                UIContentSizeCategoryExtraLarge: 2,
                UIContentSizeCategoryExtraExtraLarge: 4,
                UIContentSizeCategoryExtraExtraExtraLarge: 6,
                UIContentSizeCategoryAccessibilityMedium: 11,
                UIContentSizeCategoryAccessibilityLarge: 16,
                UIContentSizeCategoryAccessibilityExtraLarge: 23,
                UIContentSizeCategoryAccessibilityExtraExtraLarge: 30,
                UIContentSizeCategoryAccessibilityExtraExtraExtraLarge: 36,
            ]
        #endif
    }

    /// This is the default scaling function. This scaling function will continue to grow by
    /// 2 points for each step above large, and shrink by 1 point for each step below large.
    /// This function will not create larger values for content size category values in 'Accessibility Content Size Category Constants'.
    ///
    /// - parameter contentSizeCategory: The contentSizeCategory to scale to
    /// - parameter designatedSize: The size the font was designed for at UIContentSizeCategoryLarge
    /// - parameter minimiumSize: The smallest size the font can be. Defaults to 11 or designatedSize if it is under 11.
    /// - returns: The new pointSize scaled to the specified contentSize
    public static func adapt(designatedSize size: CGFloat, for contentSizeCategory: BonMotContentSizeCategory, minimiumSize: CGFloat = 11) -> CGFloat {
        let shift = min(shiftTable[contentSizeCategory] ?? 0, CGFloat(6))
        let minSize = min(minimiumSize, size)
        return max(size + shift, minSize)
    }

    /// This is a scaling function for "body" elements. This scaling function will continue to grow
    /// for content size category values in 'Accessibility Content Size Category Constants'
    ///
    /// - parameter contentSizeCategory: The contentSizeCategory to scale to
    /// - parameter designatedSize: The size the font was designed for at UIContentSizeCategoryLarge
    /// - parameter minimiumSize: The smallest size the font can be. Defaults to 11.
    /// - returns: The new pointSize scaled to the specified contentSize
    public static func adaptBody(designatedSize size: CGFloat, for contentSizeCategory: BonMotContentSizeCategory, minimiumSize: CGFloat = 11) -> CGFloat {
        let shift = shiftTable[contentSizeCategory] ?? 0
        let minSize = min(minimiumSize, size)
        return max(size + shift, minSize)
    }

}
