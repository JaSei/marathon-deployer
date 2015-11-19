FROM avastsoftware/cpanm:latest

MAINTAINER Avast Viruslab Systems

COPY deploy.pl /deployer/deploy.pl

RUN cpanm Mojolicious Path::Tiny

ENTRYPOINT ["perl"]
CMD ["/deployer/deploy.pl"]
