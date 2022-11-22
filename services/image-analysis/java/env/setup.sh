# download GraalVM
wget https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-22.3.0/graalvm-ce-java17-linux-amd64-22.3.0.tar.gz
ls
tar -xzvf graalvm-ce-java17-linux-amd64-22.3.0.tar.gz

# configure Java 17 and GraalVM 22.3
echo Existing JVM: $JAVA_HOME
cd graalvm-ce-java17-22.3.0
export JAVA_HOME=$PWD
cd bin
export PATH=$PWD:$PATH

echo JAVA HOME: $JAVA_HOME
echo PATH: $PATH

# install the native image utility
java -version
gu install native-image

cd ../..