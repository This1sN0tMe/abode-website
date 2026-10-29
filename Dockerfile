# Capstone 1 — Abode Software product image.
#
# Base is the course's pre-built image: Ubuntu 18.04, Apache 2.4.29, CMD apachectl -D FOREGROUND,
# /var/www/html already holds an index.php. Measured, not assumed:
#   docker run --rm --entrypoint sh hshar/webapp -c 'cat /etc/os-release; apache2 -v; ls /var/www/html'
#   -> Ubuntu 18.04 LTS, Apache/2.4.29, index.php, curl present, git absent
#
# COPY only. The base's apt mirrors still answer today (probed), but nothing here needs a package, and
# an image that installs nothing cannot break when a 2019 mirror finally retires.
#
# DirectoryIndex puts index.html ahead of index.php, so the product page replaces the placeholder
# without deleting anything. Verified by curling the built image, not by reading this comment.
FROM hshar/webapp:latest

COPY index.html /var/www/html/index.html
COPY images/ /var/www/html/images/

EXPOSE 80
