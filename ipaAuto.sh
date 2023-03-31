# https://developer.aliyun.com/article/931084?spm=a2c6h.12873639.article-detail.77.773b2ea1Ja27a7
#!/bin/bash
# 前提：enterprise打包时，需要切换到 企业账户 及 BundleID
# 使用方法:
# step1: 将该脚本放在工程的根目录下（跟.xcworkspace文件or .xcodeproj文件同目录）
# step2: 根据情况修改下面的参数
# step3: 打开终端，执行脚本。（输入sh，然后将脚本文件拉到终端，会生成文件路径，然后enter就可）

echo "-----------开始执行脚本-----------"

# =============项目自定义部分(自定义好下列参数后再执行该脚本)=================== #

echo "请选择打包方式 ? [1:app_store 2:ad_hoc 3:enterprise 4:development]"

read distributionMethod
while([$distributionMethod != 1] && [$distributionMethod != 2] && [$distributionMethod != 3] && [ $distributionmethod != 4])
do
echo "Error! Should enter 1 or 2 or 3 or 4 or 5"
echo "请选择打包方式 ? [ 1:app_store 2:ad_hoc 3:enterprise 4:development]"
read distributionmethod
done

echo "请选择打包环境 ? [1:Debug 2:release]"
read buildConfiguration
while([$buildConfiguration != 1] && [$buildConfiguration != 2])
do
echo "Error! Should enter 1 or 2"
echo "请选择打包环境 ? [1:Debug 2:release]"
read buildConfiguration
done

#-----------脚本配置信息-----------
# .xcworkspace的名字，必填
workspace_name="HKLayoutDemo"
# 指定项目的scheme名称（也就是工程的target名称），必填
scheme_name="HKLayoutDemo"
# 指定要打包编译的方式 : Release,Debug。一般用Release。必填
if [$buildConfiguration == 1]; then
    build_configuration="Debug"
else
    build_configuration="Release"
fi


# method，打包的方式。方式分别为 app-store、ad-hoc、enterprise、development。必填
if [$distributionMethod == 1]; then
    method="app-store"
elif [$distributionMethod == 2]; then
    method="app-store"
elif [$distributionMethod == 3]; then
    method="enterprise"
else
    method="development"
fi
#  下面两个参数只是在手动指定Pofile文件的时候用到，如果使用Xcode自动管理Profile,直接留空就好
# (跟method对应的)mobileprovision文件名，需要先双击安装.mobileprovision文件.手动管理Profile时必填
# mobileprovision_name="9d8c7290-4345-4ebf-82d4-a74cab2ea40b"
mobileprovision_name=""
# 项目的bundleID，手动管理Profile时必填
bundle_identifier=""
# if [[ $distributionmethod == 1 ]]; then
#     bundle_identifier="com.mi.global.sho"
# else
#     bundle_identifier="com.mi.global.shop"
# fi
# 每次编译后是否Build自动加1,
# 可以修改该常量的值,以决定编译后还是打包后Build自动加1
# #  0: 每次打包后Build自动加1  
# #  1: 每次编译后Build自动加1  
DEBUG_ENVIRONMENT_SYMBOL=1
# 根据选项配置不同的包

echo "--------------------脚本配置参数检查--------------------"
echo "\033[33;1mworkspace_name = ${workspace_name}"
echo "scheme_name = ${scheme_name}"
echo "build_configuration = ${build_configuration}"
echo "bundle_identifier = ${bundle_identifier}"
echo "method = ${method}"
echo "mobileprovision_name = ${mobileprovision_name} \033[0m"
# =======================脚本的一些固定参数定义(无特殊情况不用修改)====================== #
# 获取当前脚本所在目录
script_dir="$( cd "$( dirname "$0"  )" && pwd  )"
# 工程根目录
project_dir=$script_dir
# 指定输出导出文件夹路径
export_path="$project_dir/Build"
# 指定输出归档文件路径
export_archive_path="$export_path/$scheme_name.xcarchive"
# 指定输出ipa文件夹路径
export_ipa_path="$export_path/"
# 指定导出ipa包需要用到的plist配置文件的路径
export_options_plist_path="$project_dir/ExportOptions.plist"

echo "--------------------脚本固定参数检查--------------------"
echo "\033[33;1mproject_dir = ${project_dir}"
echo "export_path = ${export_path}"
echo "export_archive_path = ${export_archive_path}"
echo "export_ipa_path = ${export_ipa_path}"
echo "export_options_plist_path = ${export_options_plist_path}\033[0m"

# =======================自动打包部分(无特殊情况不用修改)====================== #
echo "------------------------------------------------------"
echo "\033[32m开始构建项目  \033[0m"
# 进入项目工程目录
cd ${project_dir}
# 指定输出文件目录不存在则创建
if [ -d "$export_path" ];
then rm -rf "$export_path"
fi
/usr/bin/xcrun xcodebuild -UseNewBuildSystem=YES -xcconfig InnerXcconfig/innerInner/tt.xcconfig
# 编译前清理工程
xcodebuild clean -workspace ${workspace_name}.xcworkspace \
                 -scheme ${scheme_name} \
                 -configuration ${build_configuration}
xcodebuild archive -workspace ${workspace_name}.xcworkspace \
                   -scheme ${scheme_name} \
                   -configuration ${build_configuration} \
                   -archivePath ${export_archive_path}
#  检查是否构建成功
#  xcarchive 实际是一个文件夹不是一个文件所以使用 -d 判断
if [ -d "$export_archive_path" ] ; then
    echo "\033[32;1m项目构建成功 🚀 🚀 🚀  \033[0m"
else
    echo "\033[31;1m项目构建失败 😢 😢 😢  \033[0m"
    exit 1
fi
echo "------------------------------------------------------"
echo "\033[32m开始导出ipa文件 \033[0m"
# 先删除export_options_plist文件
if [ -f "$export_options_plist_path" ] ; then
    #echo "${export_options_plist_path}文件存在，进行删除"
    rm -f $export_options_plist_path
fi
# 根据参数生成export_options_plist文件
/usr/libexec/PlistBuddy -c  "Add :method String ${method}"  $export_options_plist_path
/usr/libexec/PlistBuddy -c  "Add :provisioningProfiles:"  $export_options_plist_path
/usr/libexec/PlistBuddy -c  "Add :provisioningProfiles:${bundle_identifier} String ${mobileprovision_name}"  $export_options_plist_path
/usr/libexec/PlistBuddy -c  "Add :compileBitcode bool NO" $export_options_plist_path
xcodebuild  -exportArchive \
            -archivePath ${export_archive_path} \
            -exportPath ${export_ipa_path} \
            -exportOptionsPlist ${export_options_plist_path} \
            -allowProvisioningUpdates
# 检查文件是否存在
if [ -f "$export_ipa_path/$scheme_name.ipa" ] ; then
    echo "\033[32;1m导出 ${scheme_name}.ipa 包成功 🎉  🎉  🎉   \033[0m"
    open $export_path
else
    echo "\033[31;1m导出 ${scheme_name}.ipa 包失败 😢 😢 😢     \033[0m"
    exit 1
fi
# 删除export_options_plist文件（中间文件）
if [ -f "$export_options_plist_path" ] ; then
    #echo "${export_options_plist_path}文件存在，准备删除"
    rm -f $export_options_plist_path
fi
# 输出打包总用时
echo "\033[36;1m使用AutoPackageScript打包总用时: ${SECONDS}s \033[0m"
echo "------------------------------------------------------"
# AppStore上传到xxx
if [ $distributionmethod == 1 ];then 
        # 将包上传AppStore  
        ipa_path="$export_ipa_path/$scheme_name.ipa"
        # 上传AppStore的密钥ID、Issuer ID
        api_key="xxxxx"
        issuer_id="xxxxx"
    echo "--------------------AppStore上传固定参数检查--------------------"
    echo "ipa_path = ${ipa_path}"
    echo "api_key = ${api_key}"
    echo "issuer_id = ${issuer_id}"
# 校验 + 上传 方式1
    # # 校验指令
    # cnt0=`xcrun altool --validate-app -f ${ipa_path} -t ios --apiKey ${api_key} --apiIssuer ${issuer_id} --verbose`
    # echo $cnt0
    # cnt=`echo $cnt0 | grep “No errors validating archive” | wc -l`
    # if [ $cnt = 1 ] ; then
    #     echo "\033[32;1m校验IPA成功🎉  🎉  🎉 \033[0m"
    #     echo "------------------------------------------------------"
    #     cnt0=`xcrun altool --upload-app -f ${ipa_path} -t ios --apiKey ${api_key} --apiIssuer ${issuer_id} --verbose"`
    #     echo $cnt0
    #     cnt=`echo $cnt0 | grep “No errors uploading” | wc -l`
    #     if [ $cnt = 1 ] ; then
    #         echo "\033[32;1m上传IPA成功🎉  🎉  🎉 \033[0m"
    #         echo "------------------------------------------------------"
            
    #     else
    #         echo "\033[32;1m上传IPA失败😢 😢 😢   \033[0m"
    #         echo "------------------------------------------------------"
    #     fi
    # else
    #     echo "\033[32;1m校验IPA失败😢 😢 😢   \033[0m"
    #     echo "------------------------------------------------------"
    # fi
# 校验 + 上传 方式2
    # 验证
    validate="xcrun altool --validate-app -f ${ipa_path} -t ios --apiKey ${api_key} --apiIssuer ${issuer_id} --verbose"
    echo "running validate cmd" $validate
    validateApp="$($validate)"
    if [ -z "$validateApp" ]; then
        echo "\033[32m校验IPA失败😢 😢 😢   \033[0m"
        echo "------------------------------------------------------"
    else
        echo "\033[32m校验IPA成功🎉  🎉  🎉  \033[0m"
        echo "------------------------------------------------------"
        
        # 上传
        upload="xcrun altool --upload-app -f ${ipa_path} -t ios --apiKey ${api_key} --apiIssuer ${issuer_id} --verbose"
        echo "running upload cmd" $upload
        uploadApp="$($upload)"
        echo uploadApp
        if [ -z "$uploadApp" ]; then
            echo "\033[32m传IPA失败😢 😢 😢   \033[0m"
            echo "------------------------------------------------------"
        else
            echo "\033[32m上传IPA成功🎉  🎉  🎉 \033[0m"
            echo "------------------------------------------------------"
        fi
    fi
fi
exit 0