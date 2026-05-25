from datetime import datetime
from flask import Flask, render_template, request, redirect, url_for, session, send_from_directory
from werkzeug.security import generate_password_hash, check_password_hash
import json
import sqlite3
import os

app = Flask(__name__)
app.secret_key = 'lastcontrol_gizli_anahtar' # for session security
DB_PATH = "/usr/local/lastcontrol/lastcontrol.db"
AGENT_PATH = "/usr/local/lastcontrol/dist" # agent_installer.sh

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

@app.template_filter('time_ago')
def time_ago_filter(s):
    if not s: 
        return "No Data"
    try:
        past = datetime.fromisoformat(str(s))
        now = datetime.now()
        diff = now - past
        seconds = diff.total_seconds()
        
        if seconds < 60: return "Now"
        if seconds < 3600: return f"{int(seconds // 60)} min ago"
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
            
            return "Invalid Username or Password"
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
    if not session.get('logged_in'):
        return redirect(url_for('login'))
    try:
        return send_from_directory(
            directory=AGENT_PATH,
            path='lastcontrol-agent_installer.sh',
            as_attachment=True
        )
    except FileNotFoundError:
        return "Error: Agent Installer Not Found", 404

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
    # Last 5 records in inventory table
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
        print(f"Database Error: {e}")
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

@app.route('/updates/<hostname>')
def agent_updates(hostname):
    if not session.get('logged_in'):
        return redirect(url_for('login'))
    conn = get_db_connection()
    reports = conn.execute('''
        SELECT * FROM system_info
        WHERE hostname = ? AND info_type = "update_report"
        ORDER BY created_at DESC LIMIT 5
    ''', (hostname,)).fetchall()
    conn.close()
    processed_reports = []
    for r in reports:
        try:
            data = json.loads(r['info_data'])
        except Exception:
            data = {}
        processed_reports.append({
            'created_at': r['created_at'],
            'data': data
        })
    return render_template('updates.html', hostname=hostname, reports=processed_reports)

@app.route('/systemload/<hostname>')
def agent_systemload(hostname):
    if not session.get('logged_in'):
        return redirect(url_for('login'))
    conn = get_db_connection()
    reports = conn.execute('''
        SELECT *
        FROM system_info
        WHERE hostname = ?
          AND info_type = "disk_io_load"
        ORDER BY created_at DESC
        LIMIT 10
    ''', (hostname,)).fetchall()
    conn.close()
    processed_reports = []
    for r in reports:
        try:
            data = json.loads(r['info_data'])
        except Exception:
            data = {}
        processed_reports.append({
            'created_at': r['created_at'],
            'data': data
        })
    return render_template('systemload.html', hostname=hostname, reports=processed_reports)

@app.route('/packages/<hostname>')
def agent_packages(hostname):
    if not session.get('logged_in'):
        return redirect(url_for('login'))
    conn = get_db_connection()
    reports = conn.execute('''
        SELECT *
        FROM system_info
        WHERE hostname = ? AND info_type = "package_inventory"
        ORDER BY created_at DESC
        LIMIT 3
    ''', (hostname,)).fetchall()
    conn.close()
    processed_reports = []
    for r in reports:
        try:
            data = json.loads(r['info_data'])
        except Exception:
            data = {}
        packages_raw = data.get('packages', '')
        packages = []
        if packages_raw:
            for item in packages_raw.split(','):
                if '|' in item:
                    name, version = item.split('|', 1)
                    packages.append({
                        'name': name,
                        'version': version
                    })
        processed_reports.append({
            'created_at': r['created_at'],
            'data': data,
            'packages': packages
        })
    return render_template('packages.html', hostname=hostname, reports=processed_reports)

@app.route('/cves/<hostname>')
def agent_cves(hostname):
    if not session.get('logged_in'):
        return redirect(url_for('login'))
    show_all = request.args.get('all') == '1'
    conn = get_db_connection()
    if show_all:
        query_filter = ""
    else:
        query_filter = """
            AND (
                debian_status IN ('open', 'undetermined')
                OR urgency IN ('high', 'medium')
            )
           AND urgency != 'unimportant'
        """
    rows = conn.execute(f'''
        SELECT *
        FROM cve_exposure
        WHERE hostname = ?
        {query_filter}
        ORDER BY
            CASE
                WHEN debian_status = 'open' THEN 1
                WHEN debian_status = 'undetermined' THEN 2
                WHEN debian_status = 'resolved' THEN 3
                ELSE 4
            END,
            CASE
                WHEN urgency = 'high' THEN 1
                WHEN urgency = 'medium' THEN 2
                WHEN urgency = 'low' THEN 3
                WHEN urgency = 'unimportant' THEN 4
                ELSE 5
            END,
            package_name ASC,
            cve_id DESC
    ''', (hostname,)).fetchall()
    summary = conn.execute('''
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN debian_status = 'open' THEN 1 ELSE 0 END) AS open_count,
            SUM(CASE WHEN debian_status = 'resolved' THEN 1 ELSE 0 END) AS resolved_count,
            SUM(CASE WHEN debian_status = 'undetermined' THEN 1 ELSE 0 END) AS undetermined_count,
            SUM(CASE WHEN urgency = 'high' THEN 1 ELSE 0 END) AS high_count,
            SUM(CASE WHEN urgency = 'medium' THEN 1 ELSE 0 END) AS medium_count,
            SUM(CASE WHEN urgency = 'low' THEN 1 ELSE 0 END) AS low_count,
            SUM(CASE WHEN urgency = 'unimportant' THEN 1 ELSE 0 END) AS unimportant_count,
            SUM(CASE WHEN urgency = 'not yet assigned' OR urgency = '' OR urgency IS NULL THEN 1 ELSE 0 END) AS not_assigned_count,
            SUM(CASE WHEN debian_status = 'open' AND urgency = 'high' THEN 1 ELSE 0 END) AS open_high_count,
            SUM(CASE WHEN debian_status = 'open' AND urgency = 'medium' THEN 1 ELSE 0 END) AS open_medium_count
        FROM cve_exposure
        WHERE hostname = ?
    ''', (hostname,)).fetchone()
    conn.close()
    return render_template('cves.html', hostname=hostname, rows=rows, summary=summary, show_all=show_all)

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
