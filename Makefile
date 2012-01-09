tests:
		@/usr/local/bin/mocha \
			--reporter spec \
			--globals User,Cog \
			--require should
