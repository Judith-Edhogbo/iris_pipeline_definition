import pickle
import pandas as pd
from flask import Flask, request
import numpy as np
from google.cloud import storage

bucket_name = "iris_storage"
blob_name = BLOB_MODEL
blob_vec = BLOB_VECTORIZER

app = Flask(__name__)

    

    
def make_prediction(inputs):
    """
    Make a prediction using the trained model
    """
    inputs_df = pd.DataFrame(
        inputs,
        columns=["sepal.length", "sepal.width", "petal.length", "petal.width"]
        )
    
   # models_path = './models/rf.model' 
   # with open(models_path, 'rb') as f:
   #     model = pickle.load(f)
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(blob_name)
    
    with blob.open("rb") as f:
        model = pickle.load(f)
    
    predictions = model.predict(inputs_df)
  
    return predictions

    
        
@app.route("/", methods=["GET"])
def index():
    """Basic HTML response."""
    body = (
        "<html>"
        "<body style='padding: 10px;'>"
        "<h1>Welcome to my Flask API</h1>"
        "</body>"
        "</html>"
    )
    return body

@app.route("/predict", methods=["POST"])
def predict():
    print("entering predict...")
    print(request.get_json())
    data_json = request.get_json()
    print(data_json)
    sepal_length_cm = data_json["sepal.length"]
    sepal_width_cm = data_json["sepal.width"]
    petal_length_cm = data_json["petal.length"]
    petal_width_cm = data_json["petal.width"]
    
    data = np.array([[sepal_length_cm, sepal_width_cm, petal_length_cm, petal_width_cm]])
    
    return str(make_prediction(data))

if __name__ == "__main__":
    
    app.run(host='0.0.0.0')
