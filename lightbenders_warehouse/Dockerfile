FROM frappe/erpnext:v16.25.0

USER root
COPY --chown=frappe:frappe . /home/frappe/frappe-bench/apps/lightbenders_warehouse
USER frappe

RUN ./env/bin/pip install --no-deps -e apps/lightbenders_warehouse
