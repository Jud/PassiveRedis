var PassiveRedis;

PassiveRedis = require('../');

describe('Passive Redis ORM', function() {
  return it('Should load all models', function(done) {
    return PassiveRedis.loadModels(require('./models'), function() {
      (typeof User).should.equal('function');
      (typeof Cog).should.equal('function');
      (typeof nonExist).should.equal('undefined');
      return done();
    });
  });
});
