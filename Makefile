tests:
	@TESTING=true mocha \
		--reporter spec \
		--globals User,Cog \
		--require should
