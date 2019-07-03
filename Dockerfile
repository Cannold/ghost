# target image base
FROM docker.sdlocal.net/devel/stratperlbase

WORKDIR /app

COPY modules.txt /app/
RUN install-cpan-modules /app/modules.txt

COPY bin/ /app/bin/
COPY data/ /app/data/
