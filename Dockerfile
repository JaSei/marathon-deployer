FROM avastsoftware/cpanm:latest

MAINTAINER Avast Viruslab Systems

RUN cpanm Mojolicious Path::Tiny

COPY deploy.pl /deployer/deploy.pl

ENTRYPOINT ["perl"]
CMD ["/deployer/deploy.pl"]
