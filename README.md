# AutoPackageScript
An shell script that auto pack iOS ipa file.

## 用法

1. 把 Package 文件夹放至与工程同级目录下；
2. 修改 Package 目录下的plist文件里的参数，如provisioningProfiles，teamID等；
3. 修改 PackageScript.sh 把里面需要替换的内容替换成自己的信息；
4. 使用 `chmod` 命令对 PackageScript.sh 赋于执行权限；
5. 执行 `$./PackageScript.sh -h` 查看脚本用法.

## Xcode 11更新

由于Xcode11移除了Application Loader，使用Transporter代替。所以脚本中上传的命令改用xcrun altool上传，关于apple id和密码的方式或者使用apikey的方式上传到appstore，都先参考一下以下链接:

https://juejin.im/post/5dbbc051f265da4cf406f809

https://developer.apple.com/documentation/appstoreconnectapi/creating_api_keys_for_app_store_connect_api

https://support.apple.com/en-us/HT204397

