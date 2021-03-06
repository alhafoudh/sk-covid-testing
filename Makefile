DOKKU := dokku

push_dokku:
	time git push dokku master

invalidate_cloudfront_cache:
	aws cloudfront create-invalidation --distribution-id EIJAI3FE592YV --paths '/' '/testing' '/vaccination' '/testing/embed*' '/vaccination/embed*' '/firebase/configuration.js'

db_dump:
	$(DOKKU) postgres:export covid-web-postgresql > last_production_backup.dump

db_restore:
	pg_restore --no-owner --verbose --clean -d sk_covid_testing_development last_production_backup.dump

db_clean:
	rm last_production_backup.dump

update_db: db_dump db_restore db_clean

deploy: push_dokku invalidate_cloudfront_cache
