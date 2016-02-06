FROM avastsoftware/cpanm:latest

MAINTAINER Avast Viruslab Systems

COPY . /install
RUN cpanm /install

ENTRYPOINT ["deploy"]
