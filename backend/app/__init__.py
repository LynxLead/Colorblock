from flask import Flask
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_msearch import Search
from sqlalchemy.orm import close_all_sessions


from flask.json import JSONEncoder
from datetime import datetime

db = SQLAlchemy(engine_options={
    'pool_recycle': 30, 
    'pool_size': 5,
    'pool_pre_ping': True,
})
search = Search()

def create_app():
    app = Flask(__name__, instance_relative_config=True)
    app.url_map.strict_slashes = False

    try:
        app.config.from_object('instance.config')
    except:
        app.config.from_object('config')

    db_config = app.config['DATABASE']
    app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://{}:{}@{}:{}/{}'.format(
        db_config['USERNAME'], 
        db_config['PASSWORD'], 
        db_config['HOSTNAME'], 
        db_config['PORT'],
        db_config['DATABASE']
    )
    db.init_app(app)

    search.init_app(app)

    app.secret_key = app.config['SECRET_KEY']
    CORS(app, supports_credentials=True, resources={r'/*': {'origins': app.config['CORS_ORIGINS']}})

    app.json_encoder = CustomJSONEncoder

    from app.blueprints.user import user_blueprint
    app.register_blueprint(user_blueprint, url_prefix='/user')
    from app.blueprints.item import item_blueprint
    app.register_blueprint(item_blueprint, url_prefix='/item')
    from app.blueprints.tool import tool_blueprint
    app.register_blueprint(tool_blueprint, url_prefix='/tool')
    from app.blueprints.search import search_blueprint
    app.register_blueprint(search_blueprint, url_prefix='/search')
    from app.blueprints.static import static_blueprint
    app.register_blueprint(static_blueprint, url_prefix='/static')

    from app.blueprints.auth import auth_blueprint
    app.register_blueprint(auth_blueprint, url_prefix='/')
    from app.blueprints.admin.routine import routine_blueprint
    app.register_blueprint(routine_blueprint, url_prefix='/routine')
    from app.blueprints.admin.mint import mint_blueprint
    app.register_blueprint(mint_blueprint, url_prefix='/mint')

    return app


class CustomJSONEncoder(JSONEncoder):
  'Add support for serializing timedeltas'

  def default(self, o):
    if type(o) == datetime:
      return o.isoformat()
    else:
      return super().default(o)