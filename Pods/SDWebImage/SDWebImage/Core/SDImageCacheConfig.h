/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"

/// Image Cache Expire Type
typedef NS_ENUM(NSUInteger, SDImageCacheConfigExpireType) {
    /**
     * When the image cache is accessed it will update this value
     */
    SDImageCacheConfigExpireTypeAccessDate,
    /**
     * When the image cache is created or modified it will update this value (Default)
     */
    SDImageCacheConfigExpireTypeModificationDate,
    /**
     * When the image cache is created it will update this value
     */
    SDImageCacheConfigExpireTypeCreationDate,
    /**
     * When the image cache is created, modified, renamed, file attribute updated (like permission, xattr)  it will update this value
     */
    SDImageCacheConfigExpireTypeChangeDate,
};

/**
 The class contains all the config for image cache
 @note This class conform to NSCopying, make sure to add the property in `copyWithZone:` as well.
 */
@interface SDImageCacheConfig : NSObject <NSCopying>

/**
 Gets the default cache config used for shared instance or initialization when it does not provide any cache config. Such as `SDImageCache.sharedImageCache`.
 @note You can modify the property on default cache config, which can be used for later created cache instance. The already created cache instance does not get affected.
 */
@property (nonatomic, class, readonly, nonnull) SDImageCacheConfig *defaultCacheConfig;

/**
 * Whether or not to disable iCloud backup
 * Defaults to YES.
 */
@property (assign, nonatomic) BOOL shouldDisableiCloud;

/**
 * Whether or not to use memory cache
 * @note When the memory cache is disabled, the weak memory cache will also be disabled.
 * 当内存缓存被禁用时，弱内存缓存也将被禁用。
 * Defaults to YES.
 */
@property (assign, nonatomic) BOOL shouldCacheImagesInMemory;

/*
 * The option to control weak memory cache for images. When enable, `SDImageCache`'s memory cache will use a weak maptable to store the image at the same time when it stored to memory, and get removed at the same time.
 用于控制图像的弱内存缓存的选项。启用后，“SDImageCache”的内存缓存将使用弱映射表在存储到内存时同时存储图像，并同时删除图像。
 
 * However when memory warning is triggered, since the weak maptable does not hold a strong reference to image instance, even when the memory cache itself is purged, some images which are held strongly by UIImageViews or other live instances can be recovered again, to avoid later re-query from disk cache or network. This may be helpful for the case, for example, when app enter background and memory is purged, cause cell flashing after re-enter foreground.
 * Defautls to YES. You can change this option dynamically.
 */
@property (assign, nonatomic) BOOL shouldUseWeakMemoryCache;

/**
 * Whether or not to remove the expired disk data when application entering the background. (Not works for macOS)
 * Defaults to YES.
 */
@property (assign, nonatomic) BOOL shouldRemoveExpiredDataWhenEnterBackground;

/**
 * The reading options while reading cache from disk.
 * Defaults to 0. You can set this to `NSDataReadingMappedIfSafe` to improve performance.
 */
@property (assign, nonatomic) NSDataReadingOptions diskCacheReadingOptions;

/**
 * The writing options while writing cache to disk.
 * Defaults to `NSDataWritingAtomic`. You can set this to `NSDataWritingWithoutOverwriting` to prevent overwriting an existing file.
 */
@property (assign, nonatomic) NSDataWritingOptions diskCacheWritingOptions;

/**
 * The maximum length of time to keep an image in the disk cache, in seconds.
 * 将映像保留在磁盘缓存中的最大时间长度（以秒为单位）。
 *
 * Setting this to a negative value means no expiring.
 * 将此值设置为负值意味着不会过期。
 *
 * Setting this to zero means that all cached files would be removed when do expiration check.
 * 将此值设置为零意味着在执行过期检查时将删除所有缓存文件。
 *
 * Defaults to 1 week.
 */
@property (assign, nonatomic) NSTimeInterval maxDiskAge;

/**
 * The maximum size of the disk cache, in bytes.
 * Defaults to 0. Which means there is no cache size limit.
 */
@property (assign, nonatomic) NSUInteger maxDiskSize;

/**
 * The maximum "total cost" of the in-memory image cache. The cost function is the bytes size held in memory.
 * 内存中映像缓存的最大“总成本”。成本函数是内存中保存的字节大小。
 *
 * @note The memory cost is bytes size in memory, but not simple pixels count. For common ARGB8888 image, one pixel is 4 bytes (32 bits).
 * Defaults to 0. Which means there is no memory cost limit.
 */
@property (assign, nonatomic) NSUInteger maxMemoryCost;

/**
 * The maximum number of objects in-memory image cache should hold.
 * 内存图像缓存中对象的最大数量应该保持。
 * Defaults to 0. Which means there is no memory count limit.
 */
@property (assign, nonatomic) NSUInteger maxMemoryCount;

/*
 * The attribute which the clear cache will be checked against when clearing the disk cache
 * 清除磁盘缓存时检查清除缓存的属性
 * Default is Modified Date
 */
@property (assign, nonatomic) SDImageCacheConfigExpireType diskCacheExpireType;

/**
 * The custom file manager for disk cache. Pass nil to let disk cache choose the proper file manager.
 * Defaults to nil.
 * @note This value does not support dynamic changes. Which means further modification on this value after cache initlized has no effect.
 * @note Since `NSFileManager` does not support `NSCopying`. We just pass this by reference during copying. So it's not recommend to set this value on `defaultCacheConfig`.
 */
@property (strong, nonatomic, nullable) NSFileManager *fileManager;

/**
 * The custom memory cache class. Provided class instance must conform to `SDMemoryCache` protocol to allow usage.
 * Defaults to built-in `SDMemoryCache` class.
 * @note This value does not support dynamic changes. Which means further modification on this value after cache initlized has no effect.
 */
@property (assign, nonatomic, nonnull) Class memoryCacheClass;

/**
 * The custom disk cache class. Provided class instance must conform to `SDDiskCache` protocol to allow usage.
 * Defaults to built-in `SDDiskCache` class.
 * @note This value does not support dynamic changes. Which means further modification on this value after cache initlized has no effect.
 */
@property (assign ,nonatomic, nonnull) Class diskCacheClass;

@end
