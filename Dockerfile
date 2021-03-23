FROM ubuntu:xenial
MAINTAINER fschlott(test)

RUN echo "start"

# Update
RUN echo "OS package updates" && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get dist-upgrade
    
    
FROM ubuntu:xenial
MAINTAINER fschlott(test)

RUN echo "start"

# Update
RUN echo "OS package updates" && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get dist-upgrade
