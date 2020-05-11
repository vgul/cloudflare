# cloudflare
script to update cloudflare DNS


Files
  - cloudflare.conf.template      conf file with credentials;
                                  should be stored to /etc/cloudflare.conf

  - cron.d.cloudflare.template    proposed way to store for scheduling

  - cloudflare                    script to store to ~bin/
                                  this cript can be used for manual dry-run mode

  - cloudflare.sh                 subj. You have to create 
                                    /var/cache/local/cloudflare
                                  folder and give permission for user;
                                  not mandatory for root

  see clouflare.sh --help output
