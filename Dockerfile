# target image base
FROM docker.sdlocal.net/devel/stratperlbase

WORKDIR /app

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libmysqlclient-dev

COPY modules.txt /app/
RUN install-cpan-modules /app/modules.txt

ENV PATH=/app/bin:$PATH

COPY bin/ /app/bin/
COPY data/ /app/data/
