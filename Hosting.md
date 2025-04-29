<!-- (C) Copyright 2024-2025 Hewlett Packard Enterprise Development LP -->

# Requirements for Hosting BYOI files

This file describes some of the requirements enforced for the web server hosting the final BYOI ISO file.

## Secure Web Server

HPE Bare Metal requires the ISO file be hosted on an SSL-enabled web server (HTTPS). This web server's SSL
certificate must be issued by a common, public trusted Certificate Authority.

Starting with Bare Metal v0.24.143, this SSL certificate validation can be skipped for an individual file. This
can be useful for internal web servers that use either a self-signed, or private CA issued SSL certificate.
In the `files` section of the yml file, add `skip_ssl_verify: true` so the section looks like:
```
files:
  - path: "debian.tar"
    file_size: 4165683200
    display_url: "DEBIANBYOI"
    secure_url: "https://www.company.com/dir/debian-12.5.0.tar"
    skip_ssl_verify: true
    download_timeout: 5000
    signature: "f26ca6a4f772b0ea96335d7b5b6b8d201932fc94415a320228b5c7b568e1e329"
    algorithm: sha256sum
```

## Accessibility

This web server must be accessible from the On-Prem controller. This web server can be internal in the
customer network or on the public internet (ex: AWS S3, Azure Blob Storage).

## Target webserver specification

This webserver URL prefix should be specified as a command line parameter `-p <image-url-prefix>` while running
the build so the output yml file will contain the correct `secure_url`.
If you need to change the location the ISO should be downloaded from, you can modify the `secure_url` line of the
yml file without needing to rebuild the entire ISO.

## Further reading

Specific webserver configuration is beyond the scope of this document. Please see the vendor webserver
product documentation on how to create an SSL-enabled webserver to host your ISO file. Below is a
non-exhaustive list:
* Public Hosting
  * https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html
  * https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal
* Private Hosting
  * https://learn.microsoft.com/en-us/iis/manage/configuring-security/how-to-set-up-ssl-on-iis
  * https://httpd.apache.org/docs/2.4/ssl/ssl_howto.html
  * https://nginx.org/en/docs/http/configuring_https_servers.html
