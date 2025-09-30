FROM python:3.10

RUN groupadd -r uwsgi && useradd -r -g uwsgi uwsgi
RUN pip install Flask uWSGI requests redis

WORKDIR /app
COPY ./app /app
COPY boot.sh /
RUN chmod a+x /boot.sh

ENV CONTEXT PROD
ENV IMAGEBACKEND_DOMAIN imagebackend
ENV REDIS_DOMAIN redis
EXPOSE 5000 9191
USER uwsgi

CMD ["/boot.sh"]
