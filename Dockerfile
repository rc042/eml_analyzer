# build env
FROM node:18-buster-slim as build
RUN apt-get update \
  && apt-get install -y python3 spamassassin supervisor libmagic-dev build-essential \
  && apt-get clean  \
  && rm -rf /var/lib/apt/lists/*

COPY ./frontend /frontend
WORKDIR /frontend
ENV NODE_OPTIONS --openssl-legacy-provider
RUN npm install && npm run build && rm -rf node_modules

# prod env
FROM python:3.9-slim-buster

RUN apt-get update \
  && apt-get install -y python spamassassin supervisor libmagic-dev  \
  && apt-get clean  \
  && rm -rf /var/lib/apt/lists/*

RUN sa-update

WORKDIR /backend

COPY pyproject.toml poetry.lock /backend/
COPY gunicorn.conf.py /backend
COPY app /backend/app

RUN pip install poetry==1.1.15 && poetry config virtualenvs.create false && poetry install --no-dev
RUN pip install circus

COPY circus.ini /etc/circus.ini

COPY --from=build /frontend /backend/frontend

# spamd envs
ENV SPAMD_MAX_CHILDREN=1 \
  SPAMD_PORT=7833 \
  SPAMD_RANGE="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1/32"

# app envs
ENV SPAMASSASSIN_PORT=7833 \
  PORT=8000

EXPOSE $PORT

CMD ["circusd", "/etc/circus.ini"]
