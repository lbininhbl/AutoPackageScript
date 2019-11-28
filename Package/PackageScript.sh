#!/bin/bash

################# 定义常量或变量 ################
# =============================== 路径相关 ===============================  #
# 包导出的基础路径
user=`whoami`
base_export_path="/Users/$user/Desktop/IPA/"
# 当前目录路径
CURRENT_DIR=$(cd "$(dirname "$0")"; pwd)
# 获取工程目录路径。由于当前目录放在Xcode工程下，所以在当前目录的前一级目录则为Xcode工程所在目录
PROJECT_DIR=$(cd "$CURRENT_DIR/.."; pwd)
# 导出ipa所需要的plist文件路径 (默认为DevelopmentExportOptionsPlist.plist)
export_options_plist_path="$CURRENT_DIR/DevelopmentExportOptionsPlist.plist"

# =============================== 工程信息 ===============================  #
# 工程名字
project_name=`find $PROJECT_DIR -maxdepth 1 -name *.xcodeproj | awk -F "[/.]" '{print $(NF-1)}'`
# scheme_name，默认为工程名字，如果不一致，则需要手动设置
scheme_name=$project_name
# info.plist的路径
info_plist_path="$PROJECT_DIR/$project_name/Info.plist"
# build号, 默认工程中的，也可以注释以下语句，使用年月日的规则
# build_number=$(date '+%Y%m%d')
#build_number=`/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $info_plist_path`
build_number=`sed -n '/CURRENT_PROJECT_VERSION/{s/CURRENT_PROJECT_VERSION = //;s/;//;s/^[[:space:]]*//;p;q;}' ${PROJECT_DIR}/${project_name}.xcodeproj/project.pbxproj`
# 获取工程的版本号, Xcode11之后，直接读取info.plist文件里只得到 $MARKETING_VERSION 和 $CURRENT_PROJECT_VERSION，所以修改了获取方法
#bundle_version=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $info_plist_path`
bundle_version=`sed -n '/MARKETING_VERSION/{s/MARKETING_VERSION = //;s/;//;s/^[[:space:]]*//;p;q;}' ${PROJECT_DIR}/${project_name}.xcodeproj/project.pbxproj`

# =============================== 打包部分 ===============================  #
# 指定要打包编译的方式 : Release,Debug...
build_configuration="Debug"

# =============================== 初始参数 ===============================  #
# 记录打包所花费的时间
start_time=$(date +%s)
## 打包的方式[ AdHoc AppStore Development ] 默认为Development
export_option="Development"
export_folder="${export_option}/"
# 是否上传ipa
upload_ipa=false
# 是否打包RN
pack_react_native=false
# 是否是workspace
is_workspace=true
# 是否需要修改 version
is_set_version=false
# 是否需要修改 build
is_set_build=false

# =============================== 全局函数 ===============================  #
## useage 脚本用法
function useage() {
	cat << EOF
Hunlimao-iOS app build scipt
Usage: $0 <OPTIONS>
OPTIONS:
    -h  Print this usage.
    -v  Version string. Specify a version to the project when export a new ipa.
    -b  Build number string. Specify a build number to project when export a new ipa.
    -u  An option that upload the ipa. Only upload to app store when export option is AppStore, otherwise upload to pgy.
    -e  Export option. Specify it in [ AdHoc AppStore Development ]. Default is Devleopment.

    -h  打印这份说明文档
    -v  版本号，指定一个新包的版本号
    -b  build号，指定一个包的build号，默认为工程本身
    -u  上传至ipa的选项. 只有当export option是AppStore的时候会上传至AppStore，否则上传至蒲公英.
    -e  打包的方式，可以从[ AdHoc AppStore Development ]中指定任一种，默认是Development
EOF
}

# 格式化时间字符串
totalCost=""
function formatCostTime() {
	totalSecond=$1

	if [[ $totalSecond -lt 60 ]]; then
		# 秒
		totalCost="${totalSecond}s"
	elif [[ $totalSecond -lt 3600 ]]; then
		# 分
		minut=`expr $totalSecond / 60`
		second=`expr $totalSecond % 60`
		totalCost="${minut}m${second}s"
	else
		# 时
		hour=`expr $totalSecond / 3600`
		minut=`expr $totalSecond % 3600 / 60`
		second=`expr $totalSecond % 3600 % 60`
		totalCost="${hour}h${minut}m${second}s"
	fi
}


# =============================== 处理脚本的参数 ===============================  #
while getopts e:v:b:uhp OPT; do
	case $OPT in
		v)
            is_set_version=true
			bundle_version=$OPTARG
			;;
		b)
            is_set_build=true
			build_number=$OPTARG
			;;
		u)
			echo "需要上传ipa"
			upload_ipa=true
			;;
		e)
			export_option=$OPTARG
			export_folder="${export_option}/"
			export_options_plist_path="$CURRENT_DIR/${export_option}ExportOptionsPlist.plist"
			if [[ $export_option == "AppStore" || $export_option == "AdHoc" ]]; then
				build_configuration="Release"
			fi
			;;
		h)
			useage	
			exit 1
			;;
		\?)
			useage	
			exit 1
			;;
	esac
done

# =============================== 设置工程信息 ===============================  #
echo "***************** 版本号: ${bundle_version} build号: ${build_number} *****************"
# 设置版本号，build号
if $is_set_version ; then
    /usr/libexec/PlistBuddy -c "set :CFBundleShortVersionString ${bundle_version}" $info_plist_path
fi

if $is_set_build ; then
    /usr/libexec/PlistBuddy -c "set :CFBundleVersion ${build_number}" $info_plist_path
fi

# =============================== 设置路径信息 ===============================
export_path="${base_export_path}${export_folder}${scheme_name} v${bundle_version} $(date '+%Y-%m-%d %H-%M-%S')"
# 指定输出归档文件地址
date=$(date '+%Y-%m-%d')
time=$(date '+%H-%M-%S')
export_archive_path="/Users/${user}/Library/Developer/Xcode/Archives/$date/${scheme_name}${time}.xcarchive"

# =============================== 开始构建项目 ===============================  #
echo "***************** 开始构建项目 *****************"

cd "$PROJECT_DIR"

# 判断编译的项目类型是workspace还是project
if $is_workspace ; then
    # 编译前清理工程
    xcodebuild clean -workspace ${project_name}.xcworkspace \
                    -scheme ${scheme_name} \
                    -configuration ${build_configuration} \
                    -jobs 4

    xcodebuild archive -workspace ${project_name}.xcworkspace \
                    -scheme ${scheme_name} \
                    -configuration ${build_configuration} \
                    -archivePath "${export_archive_path}" \
                    -jobs 4
else
    # 编译前清理工程
    [ $cleanBeforeBuild -ne 0 ] &&
    xcodebuild clean -project ${project_name}.xcodeproj \
                    -scheme ${scheme_name} \
                    -configuration ${build_configuration} \
                    -jobs 4

    xcodebuild archive -project ${project_name}.xcodeproj \
                    -scheme ${scheme_name} \
                    -configuration ${build_configuration} \
                    -archivePath "${export_archive_path}" \
                    -jobs 4
fi

#  检查是否构建成功
#  xcarchive 实际是一个文件夹不是一个文件所以使用 -d 判断
if [ -d "$export_archive_path" ] ; then
    echo "项目构建成功 🚀 🚀 🚀 "
else
    echo "项目构建失败 😢 😢 😢 "
exit 1
fi

# =============================== 开始导出ipa ===============================  #
echo "***************** 开始导出ipa *****************"
# allowProvisioningUpdates 
xcodebuild  -exportArchive \
            -archivePath "${export_archive_path}" \
            -exportPath "${export_path}" \
            -exportOptionsPlist "${export_options_plist_path}" \
            -allowProvisioningUpdates \
            -jobs 4

# 检查文件是否存在
if [ -f "$export_path/${scheme_name}.ipa" ] ; then
	echo "导出 ${ipa_name}.ipa 包成功 🎉  🎉  🎉 "
	open "$export_path"
else
	echo "导出 ${ipa_name}.ipa 包失败 😢 😢 😢 "
	exit 1
fi

# 输出打包总用时
end_time=$(date +%s)
SECONDS=`expr $end_time - $start_time`
formatCostTime $SECONDS
echo "使用HLMAutoPackageScript打包总用时: ${totalCost}"

#ipa上传
if [[ $upload_ipa == "true" && $export_option == "AppStore" ]] ; then
	# 当输出的包是AppStore的包且选择了上传
	echo "*************************  开始验证ipa  *************************"
	
	filePath="${export_path}/${scheme_name}.ipa"
	validatexmlPath="${CURRENT_DIR}/validatexml"
	
	# xcode 11已经移除了 Application Loader了，所以这里改用xcrun命令，可以在命令台中查看使用方法。
    # 如果apple id开启了二次验证的话，则需要把密码改成指定密码，在https://appleid.apple.com/#!&page=signin登录并生成。
    # 或者使用api密钥的方式，详情参考：https://juejin.im/post/5dbbc051f265da4cf406f809
    xcrun altool --validate-app -f "${filePath}" -t ios -u "替换成你的apple id" -p "替换成你的apple id密码或者是特定密码" --output-format xml > $validatexmlPath
	
	product_errors=`/usr/libexec/PlistBuddy -c "Print :product-errors" $validatexmlPath`
	if [[ -n ${product_errors} ]]; then
		echo "验证ipa包失败 😢 😢 😢"
		echo `/usr/libexec/PlistBuddy -c "Print :product-errors:0:message" $validatexmlPath`
		exit 1
	fi

	echo "验证ipa包成功  🎉  🎉  🎉"

	rm -rf ~/.itmstransporter/ ~/.old_itmstransporter/

	echo "*************************  开始上传ipa包  *************************"
	
	uploadxmlPath="${CURRENT_DIR}/uploadxml"
	
	xcrun altool --upload-app -f "${filePath}" -t ios -u "替换成你的apple id" -p "替换成你的apple id密码或者是特定密码" --output-format xml > $validatexmlPath

	product_errors=`/usr/libexec/PlistBuddy -c "Print :product-errors" $uploadxmlPath`
	if [[ -n ${product_errors} ]]; then
		echo "上传ipa包失败 😢 😢 😢"
		echo `/usr/libexec/PlistBuddy -c "Print :product-errors:0:message" $uploadxmlPath`
		osascript -e 'display notification "上传ipa包失败 😢 😢 😢" with title "上传ipa包失败"'
	else
		echo "上传ipa包成功 🎉  🎉  🎉"
		osascript -e 'display notification "上传ipa包成功  🎉  🎉  🎉" with title "打包成功"'
	fi

elif $upload_ipa; then
	echo "*************************  开始上传ipa至蒲公英  *************************"
	# 蒲公英api https://www.pgyer.com/doc/view/api#uploadApp
	pgyer_api_key="替换成你的蒲公英apikey"
	pgyer_download_url="替换成你的下载地址"
	filePath="${export_path}/${scheme_name}.ipa"
    
    # 最后api前要多一个空格，不然会一直卡着不结束。。。。
	RESULT=$(curl -F "file=@$filePath" -F "_api_key=$pgyer_api_key" -F "buildInstallType=2" -F "buildPassword=1" https://www.pgyer.com/apiv2/app/upload)
	echo $RESULT
	echo "*************************  上传完成  *************************"
	echo "*************************  下载网址： ${pgyer_download_url}  *************************"

	osascript -e 'display notification "已上传至蒲公英" with title "打包成功"'
else	
	# 通过命令行调用通知栏信息
	osascript -e 'display notification "已完成打包" with title "打包成功"'
fi
