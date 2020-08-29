FROM ubuntu:18.04
LABEL maintainer="Odoo S.A. <info@odoo.com>"

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            ca-certificates \
            curl \
            dirmngr \
            fonts-noto-cjk \
            gnupg \
            libssl1.0-dev \
            node-less \
            python3-pip \
            python3-pyldap \
            python3-qrcode \
            python3-renderpm \
            python3-setuptools \
            python3-vobject \
            python3-watchdog \
            python3-dev \
            python3-wheel \
            python3-crypto \
            python3-cryptography \
            python3-urllib3 \
            python3-webencodings \
            python3-pypdf2 \
	    python3-psycopg2 \
            libffi-dev \
	    libcairo2-dev \
	    build-essential \
	    python3-cffi \
	    libcairo2 \
	    libpango-1.0-0 \
            libpangocairo-1.0-0 \
	    libgdk-pixbuf2.0-0 \
	    shared-mime-info \
            pkg-config \
            libsystemd-dev \
            xz-utils \
        && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb \
        && dpkg --force-depends -i wkhtmltox.deb\
        && apt-get -y install -f --no-install-recommends \
        && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# install latest postgresql-client
RUN set -x; \
        echo 'deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main' > etc/apt/sources.list.d/pgdg.list \
        && export GNUPGHOME="$(mktemp -d)" \
        && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
        && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
        && gpg --armor --export "${repokey}" | apt-key add - \
        && gpgconf --kill all \
        && rm -rf "$GNUPGHOME" \
        && apt-get update  \
        && apt-get install -y postgresql-client \
        && rm -rf /var/lib/apt/lists/*

# Create odoo user
RUN useradd -s /bin/bash -u 5001 -d /var/lib/odoo -m odoo

# Install Odoo
ENV ODOO_VERSION 11.0
ARG ODOO_RELEASE=20200829
ARG ODOO_SHA=5d8d73246ab69ffdf07fa9cab4d5bb1f0a0bbc07
RUN set -x; \
        curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
        && echo "${ODOO_SHA} odoo.deb" | sha1sum -c - \
        && apt-get update \
        && apt-get -y install --no-install-recommends ./odoo.deb \
        && rm -rf /var/lib/apt/lists/* odoo.deb

# Copy entrypoint script and Odoo configuration file
RUN pip3 install --upgrade pip setuptools
RUN pip3 install authy twilio Pycairo CairoSVG PyYAML xlwt boto3 s3transfer num2words unicodecsv phonenumbers
COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/
COPY ./requirements.txt /tmp/requirements.txt
RUN chown odoo /etc/odoo/odoo.conf
RUN pip3 install -r /tmp/requirements.txt

# Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN mkdir -p /mnt/extra-addons \
        && chown -R odoo /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8071 8072

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
