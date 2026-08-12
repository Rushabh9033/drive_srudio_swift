#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "brushed_metal" asset catalog image resource.
static NSString * const ACImageNameBrushedMetal AC_SWIFT_PRIVATE = @"brushed_metal";

/// The "carbon_weave" asset catalog image resource.
static NSString * const ACImageNameCarbonWeave AC_SWIFT_PRIVATE = @"carbon_weave";

/// The "diagonal_carbon" asset catalog image resource.
static NSString * const ACImageNameDiagonalCarbon AC_SWIFT_PRIVATE = @"diagonal_carbon";

/// The "garage_concrete" asset catalog image resource.
static NSString * const ACImageNameGarageConcrete AC_SWIFT_PRIVATE = @"garage_concrete";

/// The "hud_grid" asset catalog image resource.
static NSString * const ACImageNameHudGrid AC_SWIFT_PRIVATE = @"hud_grid";

/// The "night_noise" asset catalog image resource.
static NSString * const ACImageNameNightNoise AC_SWIFT_PRIVATE = @"night_noise";

#undef AC_SWIFT_PRIVATE
