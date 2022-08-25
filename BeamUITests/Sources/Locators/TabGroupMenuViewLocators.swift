//
//  TabGroupMenuViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 13/07/2022.
//

import Foundation

enum TabGroupMenuViewLocators {
    
    enum MenuItems: String, CaseIterable, UIElement {
        case tabGroupName = "TabGroupNameTextField"
        case tabGroupCapsuleName = "TabGroupNameStaticText"
        case tabGroupColor = "TabGroupColorPicker"
        case tabGroupNewTab = "New Tab in Group"
        case tabGroupCapture = "Capture Group to a Note…"
        case tabGroupMoveNewWindow = "Move Group in New Window"
        case tabGroupCollapse = "Collapse Group"
        case tabGroupExpand = "Expand Group"
        case tabGroupUngroup = "Ungroup"
        case tabGroupCloseGroup = "Close Group"
        case tabGroupOpenInBackground = "Open in Background"
        case tabGroupOpenInNewWindow = "Open in New Window"
        case tabGroupDeleteGroup = "Delete Group"
        case tabGroupShareGroup = "Share Group"
    }
    
    enum TabGroups: String, CaseIterable, UIElement {
        case tabGroupPrefix = "TabItem-GroupCapsule-"
    }
    
    enum ShareTabGroupMenu: String, CaseIterable, UIElement {
        case shareTwitter = "Twitter"
        case shareFacebook = "Facebook"
        case shareLinkedin = "LinkedIn"
        case shareReddit = "Reddit"
        case shareCopyLink = "Copy Link"
        case shareEmail = "Email"
        case shareMessages = "Messages"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case linkCopiedLabel = "Link Copied"
    }
}



