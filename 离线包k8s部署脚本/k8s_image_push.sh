#!/bin/bash

#--------------------------------------------
## 镜像上传说明
# 需要先在镜像仓库中创建 library 项目
# 根据实际情况更改以下私有仓库地址
#--------------------------------------------

# 定义日志
workdir=`pwd`
log_file=${workdir}/sync_images_$(date +"%Y-%m-%d").log

logger()
{
    log=$1
    cur_time='['$(date +"%Y-%m-%d %H:%M:%S")']'
    echo ${cur_time} ${log} | tee -a ${log_file}
}

images_hub() {

    while true;
    do
        read -p "输入镜像仓库地址(不加http/https): " registry
        read -p "输入镜像仓库用户名: " registry_user
        read -p "输入镜像仓库用户密码: " registry_password
        echo "您设置的仓库地址为: ${registry},用户名: ${registry_user},密码: xxx"
        read -p "是否确认(Y/N): " confirm

        if [ $confirm != Y ] && [ $confirm != y ] && [ $confirm == '' ]; then
            echo "输入不能为空，重新输入"
        else
            break
        fi
    done
}

images_hub

echo "镜像仓库 $(docker login -u ${registry_user} -p ${registry_password} ${registry})"

images=$(docker images -a | grep -v TAG | grep -v goharbor | awk '{print $1 ":" $2}')

#images=$(cat library-images.txt )

# 定义全局项目，如果想把镜像全部同步到一个仓库，则指定一个全局项目名称；
global_namespace=library

docker_push() {
    for imgs in $( echo "${images}" );
    do
        if [[ -n "$global_namespace" ]]; then

            n=$(echo ${imgs} | awk -F"/" '{print NF-1}')
            # 如果镜像名中没有/，那么此镜像一定是library仓库的镜像；
            if [ ${n} -eq 0 ]; then
                img_tag=${imgs}

                #重命名镜像
                docker tag ${imgs} ${registry}/${global_namespace}/${img_tag}
                #删除原始镜像
                #docker rmi ${imgs}
                #上传镜像
                docker push ${registry}/${global_namespace}/${img_tag}

            # 如果镜像名中有一个/，那么/左侧为项目名，右侧为镜像名和tag
            elif [ ${n} -eq 1 ]; then
                img_tag=$(echo ${imgs} | awk -F"/" '{print $2}')

                #重命名镜像
                docker tag ${imgs} ${registry}/${global_namespace}/${img_tag}
                #删除旧镜像
                #docker rmi ${imgs}
                #上传镜像
                docker push ${registry}/${global_namespace}/${img_tag}

            # 如果镜像名中有两个/，
            elif [ ${n} -eq 2 ]; then
                img_tag=$(echo ${imgs} | awk -F"/" '{print $3}')

                #重命名镜像
                docker tag ${imgs} ${registry}/${global_namespace}/${img_tag}
                #删除旧镜像
                #docker rmi ${imgs}
                #上传镜像
                docker push ${registry}/${global_namespace}/${img_tag}
            else
                #标准镜像为四层结构，即：仓库地址/项目名/镜像名:tag,如不符合此标准，即为非有效镜像。
                echo "No available images"
            fi
        else

            n=$(echo ${imgs} | awk -F"/" '{print NF-1}')
            # 如果镜像名中没有/，那么此镜像一定是library仓库的镜像；
            if [ ${n} -eq 0 ]; then
                img_tag=${imgs}
                namespace_1=library
                namespace_2=library

                #重命名镜像
                docker tag ${imgs} ${registry}/${namespace_1}/${img_tag}
                docker tag ${imgs} ${registry}/${namespace_2}/${img_tag}
                #删除原始镜像
                #docker rmi ${imgs}
                #上传镜像
                docker push ${registry}/${namespace_1}/${img_tag}
                docker push ${registry}/${namespace_2}/${img_tag}

            # 如果镜像名中有一个/，那么/左侧为项目名，右侧为镜像名和tag
            elif [ ${n} -eq 1 ]; then
                img_tag=$(echo ${imgs} | awk -F"/" '{print $2}')
                namespace=$(echo ${imgs} | awk -F"/" '{print $1}')

                #重命名镜像
                docker tag ${imgs} ${registry}/${namespace}/${img_tag}
                #删除旧镜像
                #docker rmi ${imgs}
                #上传镜像
                docker push ${registry}/${namespace}/${img_tag}

            # 如果镜像名中有两个/，
            elif [ ${n} -eq 2 ]; then
                img_tag=$(echo ${imgs} | awk -F"/" '{print $3}')
                namespace=$(echo ${imgs} | awk -F"/" '{print $2}')

                #重命名镜像
                docker tag ${imgs} ${registry}/${namespace}/${img_tag}
                #删除旧镜像
                #docker rmi ${imgs}
                #上传镜像
                docker push ${registry}/${namespace}/${img_tag}
            else
                #标准镜像为四层结构，即：仓库地址/项目名/镜像名:tag,如不符合此标准，即为非有效镜像。
                echo "No available images"
            fi
        fi
    done
}

docker_push

