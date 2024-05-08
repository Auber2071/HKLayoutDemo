#
#1. source
#     * 指定 specs 的位置，自定义添加自己的 podspec。
#     * 如果没有自定义添加 podspec，则可以不添加这一项，因为默认使用 CocoaPods 官方的 source。一旦指定了其它 source，那么就必须指定官方的 source，如上例所示。
#
# 2. platform :iOS, '8.0'
#     * 指定了开源库应该被编译在哪个平台以及平台的最低版本。
#     * 如果不指定平台版本，官方文档里写明各平台默认值为 iOS：4.3，OS X：10.6，tvOS：9.0，watchOS：2.0。
#
# 3. use_frameworks!
#     使用 frameworks 动态库替换静态库链接
#     * Swift 项目 CocoaPods 默认 use_frameworks!
#     * OC 项目 CocoaPods 默认 #use_frameworks!
#
# 4. inhibit_all_warnings!
#     * 屏蔽 CocoaPods 库里面的所有警告
#     * 这个特性也能在子 target 里面定义，如果你想单独屏蔽某 pod 里面的警告也是可以的，例如：
#         `pod 'JYCarousel', :inhibit_warnings => true`
#
# 5. workspace
#     * 指定包含所有 projects 的 Xcode workspace
#     * 如果没有指定 workspace，并且在 Podfile 所在目录下只有一个 project，那么 project 的名称会被用作 workspace 的名称
#
# 6. target ‘xxxx’ do ... end
#     * 指定特定 target 的依赖库
#     * 可以嵌套子 target 的依赖库
# 
# 7. project
#     * 默认情况下是没有指定的，当没有指定时，会使用 Podfile 目录下与 target 同名的工程
#     * 如果指定了 project，如上例所示，则 CocoaPodsTest 这个 target 只有在 CocoaPodsTest 工程中才会链接
#
# 8. inherit! :search_paths
#     * 明确指定继承于父层的所有 pod，默认就是继承的


platform :ios, '15.0'

#use_frameworks!
inhibit_all_warnings!

target 'HKLayoutDemo' do

  pod "CTMediator"
  pod 'Masonry'
  pod 'SDWebImage'
  pod 'AFNetworking'
#  pod 'JSONKit'
  pod 'MJRefresh'
  pod 'MJExtension'
  pod 'SwiftLint', configurations: ['Debug']
#  pod 'PSPDFKit', podspec: 'https://my.pspdfkit.com/pspdfkit-ios/latest.podspec'
  pod 'HandyAutoLayout'
  pod 'HandyFrame'
  pod 'YYCache'
end
