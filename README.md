# AutoPackageScript
An shell script that auto pack iOS ipa file.

## 用法

1. 把 Package 文件夹放至与工程同级目录下；
2. 修改 Package 目录下的plist文件里的参数，如provisioningProfiles，teamID等；
3. 修改 PackageScript.sh 把里面需要替换的内容替换成自己的信息；
4. 使用 `chmod` 命令对 PackageScript.sh 赋于执行权限；
5. 执行 `$./PackageScript.sh -h` 查看脚本用法.