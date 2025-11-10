from flask import Flask
import os

app = Flask(__name__)

# Helper function to get environment variables safely
def get_env(var_name):
    return os.environ.get(var_name, 'N/A')

@app.route('/')
def backend_status():
    info = {
        "Private IP": get_env('INSTANCE_PRIVATE_IP'),
        "Hostname": get_env('HOSTNAME'),
        "Instance ID": get_env('INSTANCE_ID'),
        "Instance Type": get_env('INSTANCE_TYPE'),
        "Availability Zone": get_env('AZ'),
        "Region": get_env('REGION')
    }

    html_output = f"""
    <!doctype html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>Secure Webapp Backend Status</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; }}
            h1 {{ color: #2c3e50; }}
            ul {{ line-height: 1.6; }}
            li strong {{ width: 150px; display: inline-block; }}
        </style>
    </head>
    <body>
        <h1>Secure Webapp Backend Running!</h1>
        <h2>Deployment Info:</h2>
        <ul>
            {''.join(f"<li><strong>{k}:</strong> {v}</li>" for k, v in info.items())}
        </ul>
    </body>
    </html>
    """
    return html_output

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
