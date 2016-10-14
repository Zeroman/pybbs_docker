#!/bin/sh - 

if [ ! -e /init/mysql/init ];then
    echo "init database pybbs script..."
    mysql -h localhost -uroot -p123123 -e 'create database pybbs;'
    mysql -h localhost -uroot -p123123 -D pybbs < /pybbs.sql
    echo "over database pybbs script..."
    # whoami
    touch /init/mysql/init
fi



