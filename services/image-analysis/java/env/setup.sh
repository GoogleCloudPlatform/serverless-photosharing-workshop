# download GraalVM
wget https://download.oracle.com/graalvm/17/latest/graalvm-jdk-17_linux-x64_bin.tar.gz 
tar -xzf graalvm-jdk-17_linux-x64_bin.tar.gz

# configure Java 17 and GraalVM 22.3
echo Existing JVM: $JAVA_HOME
cd graalvm-jdk-17.0.7+8.1
export JAVA_HOME=$PWD
cd bin
export PATH=$PWD:$PATH

echo JAVA HOME: $JAVA_HOME
echo PATH: $PATH
java -version

cd ../..