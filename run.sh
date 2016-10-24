#!/bin/sh - 

DC="docker-compose"

init_docker()
{
    if [ -d data/init/debug ];then
        DC="docker-compose -f debug.yml"
    fi
}

wait_sql_init()
{
    while [ ! -e /init/mysql/init ]
    do
        echo "waitting sql init ..."
        sleep 5
    done
    if [ -d /init/debug ];then
        rm -rf /usr/local/tomcat/webapps/ROOT.war
    else
        if [ ! -d /init/tomcat ];then
            mkdir -p /init/tomcat
            rm -rf /usr/local/tomcat/webapps/ROOT
        fi
    fi
    # rm -rf /usr/local/tomcat/webapps/docs
    # rm -rf /usr/local/tomcat/webapps/examples
    # rm -rf /usr/local/tomcat/webapps/manager
    # rm -rf /usr/local/tomcat/webapps/host-manager
}

check_docker()
{
    if [ -e /.dockerenv ];then
        return
    fi

    if [ ! -e docker-compose.yml ];then
        return
    fi

    images=$(grep image docker-compose.yml | sed 's/image://g' | xargs)
    for image in $images
    do
        local label=$(docker images -q $image)
        if [ -z "$label" ];then
            if [ -e docker_img.tar ];then
                docker load -i docker_img.tar
                break
            else
                docker pull $image
            fi
        fi
    done

    # check images again
    for image in $images
    do
        local label=$(docker images -q $image)
        if [ -z "$label" ];then
            echo "can't find docker image $image, exit now."
            exit 1
        fi
    done

}

start_pybbs()
{
    if [ -e /.dockerenv ];then
        wait_sql_init
        if [ -d /init/debug ];then
            # 默认 JPDA_ADDRESS=localhost:8000,docker在内网，所以要去掉localhost
            export JPDA_ADDRESS=8000
            catalina.sh jpda run
        else
            catalina.sh run
        fi
    else
        if [ ! -d pybbs-jfinal ];then
            init_source
        fi
        if [ ! -e pybbs-jfinal/target/pybbs.war ];then
            maven_build_in_docker pybbs-jfinal
        fi
        if [ ! -e pybbs-jfinal/target/pybbs.war ];then
            echo "please try again, can not find pybbs-jfinal/target/pybbs.war"
            exit 1
        fi
        check_docker
        init_docker
        $DC up -d
    fi
}

maven_build_in_docker()
{
    local prj_path=$1
    local m2_path=$PWD/m2

    local label

    label=$(docker images -q maven)
    if [ -z "$label" ];then
        docker pull maven
    fi
    label=$(docker images -q maven)
    if [ -z "$label" ];then
        echo "please pull image maven manually or try again."
        exit 1
    fi

    prj_path=$(readlink -f $prj_path)

    mkdir -p $m2_path
    if [ -e "$prj_path/pom.xml" ];then
        local docker_base="docker run -it --rm"
        local docker_bind="-v $prj_path:/usr/src/mymaven -v $m2_path:/root/.m2"
        local docker_exec="mvn clean install -Dmaven.test.skip=true"
        $docker_base $docker_bind -w /usr/src/mymaven maven $docker_exec
    fi
}

init_source()
{
    if [ ! -d pybbs-jfinal ];then
        git clone --depth 1 -b v2.3 https://github.com/tomoya92/pybbs.git pybbs-jfinal
    fi
    sed -i 's#mysql://localhost#mysql://mysql#g' ./pybbs-jfinal/src/main/resources/config.properties
    sed -i 's#redis.host=.*$#redis.host=redis#g'  ./pybbs-jfinal/src/main/resources/config.properties
}

pack_release_files()
{
    if [ ! -e docker_img.tar ];then
        images=$(grep image docker-compose.yml | sed 's/image://g'  | uniq | xargs)
        echo "packing $images ..."
        docker save -o docker_img.tar $images
        ls -lh docker_img.tar
    fi

    tar --transform 's,^,docker-pybbs/,' -czvf docker-pybbs-jfinal.tar.gz \
        run.sh init_sql.sh \
        pybbs-jfinal/pybbs.sql \
        pybbs-jfinal/target/pybbs.war \
        tomcat-users.xml server.xml \
        docker-compose.yml \
        docker_img.tar
}

init_docker

opt=$1
case "$opt" in
    init)
        init_source 
        ;;
    pack)
        pack_release_files
        ;;
    c|clean)
        $DC stop
        $DC rm -vf
        docker network rm pybbs-default
        sudo rm -rf data/
        ;;
    b|build)
        cd pybbs-jfinal
        mvn clean install
        ;;
    bd|build_in_docker)
        maven_build_in_docker pybbs-jfinal
        ;;
    stop)
        $DC stop
        ;;
    restart)
        $DC stop
        sudo rm -rf data/redis
        $DC start
        ;;
    l|log)
        $DC logs -f
        ;;
    r|run)
        rm -rf data/init/debug
        init_docker
        start_pybbs
        ;;
    d|debug)
        mkdir -p data/init/debug
        init_docker
        start_pybbs
        ;;
    uc|update_class)
        # maven compiler
        # maven war:exploded
        rsync -ah --info=name,misc1,flist0 pybbs-jfinal/target/classes/ pybbs-jfinal/target/pybbs/WEB-INF/classes
        ;;
    *)
        start_pybbs
        ;;
esac

