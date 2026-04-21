from datetime import datetime
from flask import Flask, render_template, request, redirect, url_for, session, send_from_directory
from werkzeug.security import generate_password_hash, check_password_hash
import json
import sqlite3
import os

app = Flask(__name__)
app.secret_key = 'lastcontrol_secret_key'
DB_PATH = "/usr/local/lastcontrol/lastcontrol.db"
AGENT_PATH = "/usr/local/lastcontrol/dist"

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

@app.template_filter('time_ago')
def time_ago_filter(s):
    if not s: 
        return "Data NotFound"
    try:
        past = datetime.fromisoformat(str(s))
        now = datetime.now()
        diff = now - past
        seconds = diff.total_seconds()
        
        if seconds < 60: return "Now"
        if seconds < 3600: return f"{int(seconds // 60)} min Before"
        if seconds < 86400: return f"Today {past.strftime('%H:%M')}"
        if seconds < 172800: return f"Yesterday {past.strftime('%H:%M')}"
        return f"{diff.days} day ago"
    except Exception as e:
        return str(s)

@app.route('/')
def index():
    if not session.get('logged_in'): return redirect(url_for('login'))
    conn = get_db_connection()
    agents = conn.execute('SELECT * FROM agents ORDER BY last_seen DESC').fetchall()
    conn.close()
    return render_template('index.html', agents=agents)

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        try:
            username = request.form.get('username')
            password = request.form.get('password')
            
            conn = get_db_connection()
            user = conn.execute('SELECT * FROM users WHERE username = ?', (username,)).fetchone()
            conn.close()

            if user is not None:
                stored_password = str(user['password'])
                if check_password_hash(stored_password, password):
                    session['logged_in'] = True
                    return redirect(url_for('index'))
            
            return "Incorrect Username or Password!"
        except Exception as e:
            print(f"LOGIN ERROR: {e}")
            return f"System Error: {e}", 500
            
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return redirect(url_for('login'))

@app.route('/download-agent')
def download_agent():
    if not session.get('logged_in'): return redirect(url_for('login'))
    return send_from_directory(directory=AGENT_PATH, path='agent_installer.sh', as_attachment=True)

@app.route('/change-password', methods=['GET', 'POST'])
def change_password():
    if not session.get('logged_in'): return redirect(url_for('login'))
    if request.method == 'POST':
        new_password = request.form['new_password']
        hashed_password = generate_password_hash(new_password)
        conn = get_db_connection()
        conn.execute('UPDATE users SET password = ? WHERE username = ?', (hashed_password, "admin"))
        conn.commit()
        conn.close()
        return redirect(url_for('index'))
    return render_template('change_password.html')

@app.route('/agent/<hostname>')
def agent_detail(hostname):
    conn = get_db_connection()
    # Last 5 records
    reports = conn.execute('''
        SELECT * FROM inventory 
        WHERE hostname = ? 
        ORDER BY created_at DESC 
        LIMIT 5
    ''', (hostname,)).fetchall()
    conn.close()
    return render_template('inventory.html', hostname=hostname, reports=reports)

@app.route('/ports/<hostname>')
def agent_ports(hostname):
    if not session.get('logged_in'): 
        return redirect(url_for('login'))
    conn = get_db_connection()
    all_ports = conn.execute('''
        SELECT * FROM system_info 
        WHERE hostname = ? AND info_type = "open_ports" 
        ORDER BY created_at DESC LIMIT 5
    ''', (hostname,)).fetchall()
    conn.close()
    return render_template('ports.html', hostname=hostname, all_ports=all_ports)

@app.route('/disk/<hostname>')
def agent_disk(hostname):
    if not session.get('logged_in'): 
        return redirect(url_for('login'))
    conn = get_db_connection()
    all_disk_reports = conn.execute('''
        SELECT * FROM system_info 
        WHERE hostname = ? AND info_type = "disk_usage" 
        ORDER BY created_at DESC LIMIT 5
    ''', (hostname,)).fetchall()
    conn.close()
    return render_template('disk.html', hostname=hostname, all_disk_reports=all_disk_reports)

@app.route('/roles/<hostname>')
def agent_roles(hostname):
    if not session.get('logged_in'): return redirect(url_for('login'))
    conn = get_db_connection()
    try:
        reports = conn.execute('''
            SELECT * FROM system_info
            WHERE hostname = ? AND info_type = "roles"
            ORDER BY created_at DESC LIMIT 5
        ''', (hostname,)).fetchall()
    except Exception as e:
        print(f"Veritabanı hatası: {e}")
        reports = []
    finally:
        conn.close()
    return render_template('roles.html', hostname=hostname, all_roles_reports=reports)

@app.route('/users/<hostname>')
def local_users(hostname):
    if not session.get('logged_in'): return redirect(url_for('login'))
    conn = get_db_connection()
    reports = conn.execute('''
        SELECT * FROM system_info 
        WHERE hostname = ? AND info_type = "local_users" 
        ORDER BY created_at DESC LIMIT 5
    ''', (hostname,)).fetchall()
    conn.close()
    return render_template('users.html', hostname=hostname, all_reports=reports)

@app.route('/ram/<hostname>')
def agent_ram(hostname):
    if not session.get('logged_in'): return redirect(url_for('login'))
    conn = get_db_connection()
    reports = conn.execute('''
        SELECT * FROM system_info WHERE hostname = ? AND info_type = "ram_usage" 
        ORDER BY created_at DESC LIMIT 5
    ''', (hostname,)).fetchall()
    conn.close()
    processed_reports = []
    for r in reports:
        processed_reports.append({
            'created_at': r['created_at'],
            'data': json.loads(r['info_data'])
        })
    return render_template('ram.html', hostname=hostname, reports=processed_reports)

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
