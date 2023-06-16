FROM postgres:15

ENV PGTAP_VERSION=1.2.0

RUN apt-get update \
  && apt-get install -y libtap-parser-sourcehandler-pgtap-perl build-essential postgresql-server-dev-all wget \
  # Install pgTap from source (needed for the generated install/uninstall scripts)
  && wget "https://github.com/theory/pgtap/archive/v${PGTAP_VERSION}.tar.gz" \
  && tar -zxf "v${PGTAP_VERSION}.tar.gz" \
  && cd "pgtap-${PGTAP_VERSION}" \
  && make \
  && make install \
  && cd - \
  # Cleanup
  && rm -rf "v${PGTAP_VERSION}.tar.gz" \
  && rm -rf "pgtap-${PGTAP_VERSION}" \
  && rm -rf /root/.cpan \
  && apt-get remove -y build-essential postgresql-server-dev-all wget \
  && apt-get clean -y \
  && apt-get autoremove -y

# Configure non-root user
ENV USERNAME=app
RUN useradd --create-home ${USERNAME}
WORKDIR /home/app
USER ${USERNAME}

COPY pgtap_run.sh /bin/pgtap_run
COPY --chown=${USERNAME} install_pgtap.sql uninstall_pgtap.sql ./

CMD ["pgtap_run"]

