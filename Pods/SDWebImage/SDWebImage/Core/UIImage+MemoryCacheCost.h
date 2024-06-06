/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageCompat.h"

/**
 UIImage category for memory cache cost.
 */
@interface UIImage (MemoryCacheCost)

/**
 The memory cache cost for specify image used by image cache. The cost function is the bytes size held in memory.
 图像缓存使用的指定图像的内存缓存成本。成本函数是内存中保存的字节大小。
 
 If you set some associated object to `UIImage`, you can set the custom value to indicate the memory cost.
 如果将某些关联对象设置为“UIImage”，则可以设置自定义值以指示内存开销。
 
 For `UIImage`, this method return the single frame bytes size when `image.images` is nil for static image. Retuen full frame bytes size when `image.images` is not nil for animated image.
 对于“UIImage”，当静态图像的“image.images”为零时，此方法返回单帧字节大小。当动画图像的“image.images”不为零时，重新调整全帧字节大小。
 
 For `NSImage`, this method return the single frame bytes size because `NSImage` does not store all frames in memory.
 对于“NSImage”，此方法返回单帧字节大小，因为“NSImage”不会将所有帧存储在内存中。
 
 @note Note that because of the limitations of category this property can get out of sync if you create another instance with CGImage or other methods.
 请注意，由于类别的限制，如果使用 CGImage 或其他方法创建另一个实例，则此属性可能会不同步。
 
 @note For custom animated class conforms to `SDAnimatedImage`, you can override this getter method in your subclass to return a more proper value instead, which representing the current frame's total bytes.
 对于符合“SDAnimatedImage”的自定义动画类，可以在子类中重写此 getter 方法，以返回更合适的值，该值表示当前帧的总字节数。
 */
@property (assign, nonatomic) NSUInteger sd_memoryCost;

@end
