FROM composer:latest AS composer
FROM alpine:3.10
LABEL Maintainer="Marcelo Motta <marcelo.motta@sp.agence.com.br>"

COPY --from=composer /usr/bin/composer /usr/bin/composer

# Install packages
RUN apk --no-cache add php7 php7-fpm php7-pdo_mysql php7-json php7-openssl php7-curl \
    php7-zlib php7-xml php7-phar php7-intl php7-dom php7-xmlreader php7-ctype php7-session \
    php7-mbstring php7-gd php7-simplexml php7-tokenizer php7-fileinfo php7-xmlwriter php7-redis nginx curl

# Configure nginx
COPY environment/nginx.conf /etc/nginx/conf.d/default.conf
# Remove default server definition
# RUN rm /etc/nginx/conf.d/default.conf

# Configure PHP-FPM
COPY environment/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY environment/php.ini /etc/php7/conf.d/custom.ini
COPY environment/php-fpm.conf /etc/php7/php-fpm.conf

# Configure supervisord
# COPY environment/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD ./environment/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody.nobody /run && \
  mkdir /run/nginx && \
  chown -R nobody.nobody /var/lib/nginx && \
  chown -R nobody.nobody /var/tmp/nginx && \
  chown -R nobody.nobody /var/log/nginx

# Setup document root
RUN mkdir -p /var/www/html

# Make the document root a volume
# VOLUME /var/www/html

# Add application
WORKDIR /var/www/html
COPY --chown=nobody . /var/www/html/
COPY --chown=nobody .env-development /var/www/html/.env
RUN composer install --no-interaction --prefer-dist && \
  chown nobody:nobody -R ./vendor && \
  cp .env-nonprod .env && \
  php artisan config:cache && \
  php artisan view:clear && \
  php artisan cache:clear


# Switch to use a non-root user from here on
# USER nobody

# Expose the port nginx is reachable on
EXPOSE 80

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:80

# Let supervisord start nginx & php-fpm
# CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
CMD ["nginx", "-g", "daemon off;"]
ENTRYPOINT ["sh", "/usr/local/bin/docker-entrypoint.sh"]