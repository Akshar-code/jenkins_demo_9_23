FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

# Update and install necessary packages
RUN microdnf update -y && \
    microdnf install -y httpd && \
    microdnf clean all

# Copy application files
COPY . /var/www/html/

# Expose port 80
EXPOSE 80

# Start Apache HTTP Server
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]