docker环境一键部署pybbs
================


1. 初始化
```bash
# 自动下载pybbs源代码
# 修改src/main/resources/config.properties,
# 配置mysql服务器和redis服务器

./run.sh init

```


2. 编译

- 本机maven编译
```
./run.sh b
```

- docker maven编译
```
./run.sh bd
```


2. 调试运行

- 运行的前提是docker正确安装
- 在tomcat里面运行的目录是pybbs/target/pybbs
- 调试直接远程本地8000端口即可
```bash
./run.sh d
```


3. 访问

> http://localhost:8080


4. WAR部署
- 在tomcat里面运行的pybbs/target/pybbs.war
- 不能调试
```bash
./run.sh 
```


4. 停止清除等等

- 停止
```
./run.sh stop
```

- 清除 
```
./run.sh c
```

- 重启
```
./run.sh restart
```


