FROM tomcat:9.0.36-jdk14-openjdk-slim-buster
ENV http_proxy http://www.bessy.de:3128
ENV https_proxy http://www.bessy.de:3128
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update \
&& apt-get -y install sudo \
&& apt-get -y install apt-utils  \
&& apt-get -y install build-essential \
&& apt-get -y install dialog \
&& apt-get -y install curl \
&& apt-get -y install tar \
&& apt-get -y install unzip \
&& apt-get -y install apache2 \
&& apt-get -y install python2.7

# Configure jsvc
RUN cd /usr/local/tomcat/bin/ \
&& tar -zxf commons-daemon-native.tar.gz
RUN cd /usr/local/tomcat/bin/commons-daemon-1.2.2-native-src/unix \
&& ./configure \
&& make \
&& cp jsvc ../../../bin/

# Get the archiver
WORKDIR /aa
ENV RELEASE=v0.0.1_SNAPSHOT_13-Nov-2019
ENV RELEASE_FILE=archappl_v0.0.1_SNAPSHOT_13-November-2019T15-45-42.tar.gz
RUN curl -OL https://github.com/slacmshankar/epicsarchiverap/releases/download/${RELEASE}/${RELEASE_FILE}
RUN tar -xf ${RELEASE_FILE} && rm ${RELEASE_FILE}
RUN ls

# Copy the appliances.xml file
COPY etc/archappl/appliances.xml /etc/archappl/

# Set Environment Variables
ENV ARCHAPPL_APPLIANCES=/etc/archappl/appliances.xml
ENV ARCHAPPL_MYIDENTITY=appliance0
ENV TOMCAT_HOME=/usr/local/tomcat

# Create the 4 tomcats
ENV ARCHAPPL_DEPLOY_DIR=/etc/archappl/tomcats
RUN cd /aa/install_scripts/ \
&& python2.7 deployMultipleTomcats.py $ARCHAPPL_DEPLOY_DIR

# Copy the and deploy the WAR files
RUN bash -xc "\
pushd ${ARCHAPPL_DEPLOY_DIR}/mgmt/webapps && rm -rf mgmt*; cp /aa/mgmt.war .; mkdir mgmt; cd mgmt; jar xf ../mgmt.war; popd;"

RUN bash -xc "\
pushd ${ARCHAPPL_DEPLOY_DIR}/engine/webapps && rm -rf engine*; cp /aa/engine.war .; mkdir engine; cd engine; jar xf ../engine.war; popd;"

RUN bash -xc "\
pushd ${ARCHAPPL_DEPLOY_DIR}/etl/webapps && rm -rf etl*; cp /aa/etl.war .; mkdir etl; cd etl; jar xf ../etl.war; popd;"

RUN bash -xc "\
pushd ${ARCHAPPL_DEPLOY_DIR}/retrieval/webapps && rm -rf retrieval*; cp /aa/retrieval.war .; mkdir retrieval; cd retrieval; jar xf ../retrieval.war; popd;"

# Copy across the appliances.xml
COPY etc/archappl/appliances.xml /etc/archappl/

# Copy across the appliance properties
COPY etc/archappl/archappl.properties /etc/archappl/

# Copy across the policies file
COPY etc/archappl/policies.py /etc/archappl/

# Copy accross the log4j.properties used by tomcat
COPY etc/archappl/log4j.properties /etc/archappl/

# Folders we store data and logs in
# (may mount them from the host machine):
RUN mkdir -p /storage/{sts,mts,lts,logs}
RUN ln -s /etc/archappl/log4j.properties /usr/local/tomcat/lib/log4j.properties
#RUN mv /usr/local/tomcat/conf/server.xml{,.dist} && ln -s /etc/archappl/tomcat_conf_server.xml /usr/local/tomcat/conf/server.xml
RUN rmdir /usr/local/tomcat/logs && ln -s /storage/logs /usr/local/tomcat/logs

# Be generous with the heap
ENV JAVA_OPTS="-XX:+UseG1GC -Xms4G -Xmx4G -ea"

# Set up Tomcat home
ENV TOMCAT_HOME=/usr/local/tomcat
ENV CATALINA_HOME=$TOMCAT_HOME
ENV CATALINA_BASE=$ARCHAPPL_DEPLOY_DIR

# Set up the root folder of the individual Tomcat instances.
ENV ARCHAPPL_POLICIES=/etc/archappl/policies.py
ENV ARCHAPPL_PROPERTIES_FILENAME=/etc/archappl/archappl.properties
ENV ARCHAPPL_PERSISTENCE_LAYER=org.epics.archiverappliance.config.persistence.InMemoryPersistence
ENV ARCHAPPL_SHORT_TERM_FOLDER=/storage/sts
ENV ARCHAPPL_MEDIUM_TERM_FOLDER=/storage/mts
ENV ARCHAPPL_LONG_TERM_FOLDER=/storage/lts
ENV EPICS_CA_AUTO_ADDR_LIST=yes
ENV EPICS_CA_ADDR_LIST=

CMD ["/bin/bash"]
