/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2021 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#define USE_TI_UINAVIGATIONWINDOW

#import <TitaniumKit/TiProxy.h>
#import <TitaniumKit/TitaniumKit.h>
#import <TitaniumKit/TiViewController.h>
#import <TitaniumKit/TiViewProxy.h>
#import "TiUINavigationWindowProxy.h"
#import "TiUINavigationWindowInternal.h"
#import "TiWindowProxy+Addons.h"

@interface TiBottomsheetcontrollerProxy : TiProxy <UISheetPresentationControllerDelegate, TiProxyObserver> {
  CGSize TiBottomSheetContentSize;
  UIViewController *viewController;
  UISheetPresentationController *bottomSheet API_AVAILABLE(ios(15.0), macCatalyst(15.0));
  NSDictionary *userDetents;
  NSDictionary *customDetents;
  UIEdgeInsets bottomSheetSafeAreaInset;
  TiViewProxy *contentViewProxy;
  TiViewProxy *closeButtonProxy;
  UIView *closeButtonView;
  BOOL animated;
  BOOL bottomSheetInitialized;
  BOOL eventFired;
  BOOL isDismissing;
  BOOL dismissible;
  BOOL deviceRotated;
  TiDimension poWidth;
  TiDimension poHeight;
  NSString *initalSelectedDetent;
}

@property (assign, nonatomic) TiViewProxy * _Nonnull viewProxy;
@property(nonatomic, copy) NSArray<UISheetPresentationControllerDetent *> *detents API_AVAILABLE(ios(15.0), macCatalyst(15.0));
@property(nonatomic, copy, nullable) UISheetPresentationControllerDetentIdentifier largestUndimmedDetentIdentifier API_AVAILABLE(ios(15.0), macCatalyst(15.0));

@end
