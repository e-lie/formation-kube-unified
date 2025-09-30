from flask import Flask, Response, request, abort
from flask import jsonify
import requests
import hashlib
import logging
import redis
import socket
import os


imagebackend_domain = os.environ['IMAGEBACKEND_DOMAIN']
redis_domain = os.environ['REDIS_DOMAIN']

app = Flask(__name__)
redis_cache = redis.StrictRedis(host=redis_domain, port=6379, socket_connect_timeout=2, socket_timeout=2, db=0)
salt = "UNIQUE_SALT"
default_name = 'John Doe'

@app.route('/', methods=['GET', 'POST'])
def mainpage():

    try:
        visits = redis_cache.incr("counter")
    except redis.RedisError:
        visits = "<i>cannot connect to Redis, counter disabled</i>"

    name = default_name
    if request.method == 'POST':
        name = request.form['name']
    salted_name = salt + name
    name_hash = hashlib.sha256(salted_name.encode()).hexdigest()
    hostname = socket.gethostname()

    page = f'''
        <html>
          <head>
            <title>Monster Icon</title>
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/skeleton/2.0.4/skeleton.css">
          </head>
          <body style="text-align: center">
                <h1>Monster Icon</h1>
                <form method="POST">
                <strong>Hello dear <input type="text" name="name" value="{name}">
                <input type="submit" value="submit"> !
                </form>
                <div>
                  <h4>Here is your monster icon :</h4>
                  <img src="/monster/{name_hash}"/>
                <div>

          </br></br><h4> container info: </h4>
          <ul>
           <li>Hostname: {hostname}</li>
           <li>Visits: {visits} </li>
          </ul></strong>
        </body>
       </html>
    '''
    return page


@app.route('/monster/<name>')
def get_identicon(name):
    found_in_cache = False
    try:
        image = cache.get(name)
        redis_unreachable = False
        if image is not None:
            found_in_cache = True
            logging.info("Image trouvée dans le cache")
    except:
        redis_unreachable = True
        logging.warning("Cache redis injoignable")

    if not found_in_cache:
        logging.info("Image non trouvée dans le cache")
        try:
            r = requests.get(f'http://{imagebackend_domain}:8080/monster/{name}?size=100')
            image = r.content
            logging.info("Image générée grâce au service dnmonster")

            if not redis_unreachable:
                cache.set(name, image)
                logging.info("Image enregistrée dans le cache redis")
        except:
            logging.critical("Le service dnmonster est injoignable !")
            abort(503)

    return Response(image, mimetype='image/png')

@app.route('/healthz')
def healthz():
    data = {'ready': 'true'}
    return jsonify(data)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')