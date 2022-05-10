#!/usr/bin/python3
from flask import Flask
from flask import render_template
import json

app = Flask(__name__)

@app.route("/")
def index():
    print('The main function was called')
    with open('data/products.json') as f:
        data = json.load(f)

    return render_template('index.html', products=data)

if __name__ == "__main__":
    app.run(debug=True)