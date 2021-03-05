#!/bin/bash

# 当前目录路径
CURRENT_DIR=$(cd "$(dirname "$0")"; pwd)

# 验证iap包
function validateIPA() {
    validatexmlPath="${CURRENT_DIR}/validatexml"
    echo "*************************  开始验证ipa  *************************"
    echo "验证的文件地址: $1"
    # xcode 11已经移除了 Application Loader了，所以这里改用xcrun命令，可以在命令台中查看使用方法。
    # 如果apple id开启了二次验证的话，则需要把密码改成指定密码，在https://appleid.apple.com/#!&page=signin登录并生成。
    # 或者使用api密钥的方式，详情参考：https://juejin.im/post/5dbbc051f265da4cf406f809
    xcrun altool --validate-app -f "$1" -t ios -u "替换成你的apple id" -p "替换成你的apple id密码或者是特定密码" --output-format xml > $validatexmlPath
    
    product_errors=`/usr/libexec/PlistBuddy -c "Print :product-errors" $validatexmlPath`
    if [[ -n ${product_errors} ]]; then
        echo "验证ipa包失败 😢 😢 😢"
        echo `/usr/libexec/PlistBuddy -c "Print :product-errors:0:message" $validatexmlPath`
        exit 1
    fi

    echo "验证ipa包成功  🎉  🎉  🎉"
    rm -rf ~/.itmstransporter/ ~/.old_itmstransporter/
}

# 上传IAP
function uploadIAP() {
    echo "*************************  开始上传ipa包  *************************"
    
    uploadxmlPath="${CURRENT_DIR}/uploadxml"
    
    forword=1
    while forword==1;
    do
        xcrun altool --upload-app -f "$1" -t ios -u "替换成你的apple id" -p "j替换成你的apple id密码或者是特定密码" --verbose --output-format xml > $uploadxmlPath

        product_errors=`/usr/libexec/PlistBuddy -c "Print :product-errors" $uploadxmlPath`
        if [[ -n ${product_errors} ]]; then
            echo "上传ipa包失败 😢 😢 😢"
            echo `/usr/libexec/PlistBuddy -c "Print :product-errors:0:message" $uploadxmlPath`
            osascript -e 'display notification "上传ipa包失败 😢 😢 😢" with title "上传ipa包失败"'
            
            read -n1 -p "上传失败，是否重新上传?(按n不上传，任意键继续) " retry
            
            case $retry in
            (N | n)
                forword=0
                echo "不上传"
                break
                ;;
            esac
        else
            echo "上传ipa包成功 🎉  🎉  🎉"
            osascript -e 'display notification "上传ipa包成功  🎉  🎉  🎉" with title "打包成功"'
            rm -f "$uploadxmlPath"
            rm -f "$validatexmlPath"
            break
        fi
    done
}

validateIPA "$1"
uploadIAP "$1"
