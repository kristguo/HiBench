#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

echo "========== running nutchindex data =========="
# configure
DIR=`cd $bin/../; pwd`
. "${DIR}/../bin/hibench-config.sh"
. "${DIR}/conf/configure.sh"

TMP_DIR="/tmp"
export COMMON_DEPENDENCY_DIR=$HIBENCH_HOME"/common/hibench/common/target/dependency"
export NUTCHINDEXING_DEPENDENCY_DIR=$HIBENCH_HOME"/common/hibench/nutchindexing/target/dependency"

mvn -f $HIBENCH_HOME"/common/hibench/pom.xml" process-sources
common_jar_counts=`ls -1 $COMMON_DEPENDENCY_DIR/*.jar 2>/dev/null | wc -l`
nutchindexing_jar_counts=`ls -1 $NUTCHINDEXING_DEPENDENCY_DIR/*.jar 2>/dev/null | wc -l`
if [ $common_jar_counts == 0 -o $nutchindexing_jar_counts == 0 ]; then
  echo "Error: Cannot download jar dependencies by maven, please check!"
  exit
fi


if [ $HADOOP_VERSION == "hadoop1" -a -e $DIR"/nutch/conf/nutch-site-mr1.xml" ]; then
  mv $DIR/nutch/conf/nutch-site.xml $DIR/nutch/conf/nutch-site-mr2.xml
  mv $DIR/nutch/conf/nutch-site-mr1.xml $DIR/nutch/conf/nutch-site.xml
elif [ $HADOOP_VERSION == "hadoop2" -a -e $DIR"/nutch/conf/nutch-site-mr2.xml" ]; then
  mv $DIR/nutch/conf/nutch-site.xml $DIR/nutch/conf/nutch-site-mr1.xml
  mv $DIR/nutch/conf/nutch-site-mr2.xml $DIR/nutch/conf/nutch-site.xml
fi

if [ ! -e $TMP_DIR"/apache-nutch-1.2-bin.tar.gz" ]; then
  wget -P $TMP_DIR http://archive.apache.org/dist/nutch/apache-nutch-1.2-bin.tar.gz
fi
if [ ! -e $TMP_DIR"/apache-nutch-1.2-bin.tar.gz" ]; then
  echo "Error: Cannot download apache-nutch-1.2-bin.tar.gz, please check your wget!"
  exit
fi

cd $TMP_DIR
if [ ! -d $TMP_DIR"/nutch-1.2" ]; then
  tar zxf apache-nutch-1.2-bin.tar.gz
fi

NUTCH_HOME=$TMP_DIR/nutch-1.2
rm -rf $NUTCH_HOME/conf/*
rm -rf $NUTCH_HOME/bin/*
cp $DIR/nutch/conf/nutch-site.xml $NUTCH_HOME/conf
cp $DIR/nutch/bin/nutch $NUTCH_HOME/bin
mkdir $NUTCH_HOME/temp
unzip -q $NUTCH_HOME/nutch-1.2.job -d $NUTCH_HOME/temp
rm $NUTCH_HOME/temp/lib/jcl-over-slf4j-*.jar
cp $COMMON_DEPENDENCY_DIR/jcl-over-slf4j-*.jar $NUTCH_HOME/temp/lib
rm $NUTCH_HOME/nutch-1.2.job
cd $NUTCH_HOME/temp
zip -qr $NUTCH_HOME/nutch-1.2.job *
cd $NUTCH_HOME
rm -rf $NUTCH_HOME/temp

if [ -d $TMP_DIR"/nutch-1.2/lib" ]; then
  rm -rf $TMP_DIR"/nutch-1.2/lib"
fi

check_compress

# path check
$HADOOP_EXECUTABLE $RMDIR_CMD $INPUT_HDFS/indexes

# pre-running
SIZE=`dir_size $INPUT_HDFS`
#SIZE=`$HADOOP_EXECUTABLE fs -dus $INPUT_HDFS |  grep -o [0-9]* `
export NUTCH_CONF_DIR=$HADOOP_CONF_DIR:$NUTCH_HOME/conf
START_TIME=`timestamp`

# run bench
$NUTCH_HOME/bin/nutch index $COMPRESS_OPTS $INPUT_HDFS/indexes $INPUT_HDFS/crawldb $INPUT_HDFS/linkdb $INPUT_HDFS/segments/*

# post-running
END_TIME=`timestamp`
gen_report "NUTCHINDEX" ${START_TIME} ${END_TIME} ${SIZE}
