# download GraalVM
wget https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-22.2.0/graalvm-ce-java17-linux-amd64-22.2.0.tar.gz
ls
tar -xzvf graalvm-ce-java17-linux-amd64-22.2.0.tar.gz

# configure Java 17 and GraalVM 22.2
echo $JAVA_HOME
cd graalvm-ce-java17-22.2.0
export JAVA_HOME=~/graalvm-ce-java17-22.2.0
cd bin
export PATH=$PWD:$PATH

echo $JAVA_HOME
echo $PATH

java -version
gu install native-image

