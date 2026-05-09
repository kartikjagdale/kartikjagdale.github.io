FROM jekyll/jekyll:latest

WORKDIR /srv/jekyll

COPY . .

RUN bundle install

CMD ["jekyll", "serve", "--watch", "--host", "0.0.0.0"]