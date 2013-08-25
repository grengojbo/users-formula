include:
  - users.sudo

{% for name, user in pillar.get('users', {}).items() %}
{% if user == None %}
{% set user = {} %}
{% endif %}
{% set home_root = pillar.get('home_root', '/home/') %}
{% set home_mode = pillar.get('home_mode', 0755) %}
{% set home = user.get('home', "{0}{1}".format(home_root, name)) %}

{% for group in user.get('groups', []) %}
{{ group }}_group:
  group:
    - name: {{ group }}
    - present
{% endfor %}

{{ name }}_user:
  file.directory:
    - name: {{ home }}
    - user: {{ name }}
    - group: {{ name }}
    - mode: {{ home_mode }}
    - require:
      - user: {{ name }}
      - group: {{ name }}
  group.present:
    - name: {{ name }}
  user.present:
    - name: {{ name }}
    - home: {{ home }}
    - shell: {{ pillar.get('shell', '/bin/bash') }}
    {% if 'uid' in user -%}
    - uid: {{ user['uid'] }}
    {% endif %}
    {% if 'gid' in user -%}
    - gid: {{ user['gid'] }}
    {% endif %}
    - gid_from_name: True
    {% if 'fullname' in user %}
    - fullname: {{ user['fullname'] }}
    {% endif %}
    - groups:
        - {{ name }}
      {% for group in user.get('groups', []) %}
        - {{ group }}
      {% endfor %}
    - require:
        - group: {{ name }}
      {% for group in user.get('groups', []) %}
        - group: {{ group }}
      {% endfor %}

user_keydir_{{ name }}:
  file.directory:
    - name: {{ user.get('home', '/home/{0}'.format(name)) }}/.ssh
    - user: {{ name }}
    - group: {{ name }}
    - makedirs: True
    - mode: 744
    - require:
      - user: {{ name }}
      - group: {{ name }}
      {% for group in user.get('groups', []) %}
      - group: {{ group }}
      {% endfor %}

{{ home }}/bin:
  file.directory:
    - makedirs: True
    - user: {{ name }}
    - group: {{ name }}
    - makedirs: True
    - dir_mode: 775
    - recurse:
      - user
      - group
      - mode
    - require:
      - user: {{ name }}

  {% if 'privkey' in user %}
user_{{ name }}_private_key:
  file.managed:
    - name: {{ user.get('home', '/home/{0}'.format(name)) }}/.ssh/id_rsa
    - user: {{ name }}
    - group: {{ name }}
    - mode: 600
    - source: salt://keys/{{ user['privkey'] }}
    - require:
      - user: {{ name }}_user
      {% for group in user.get('groups', []) %}
      - group: {{ group }}_group
      {% endfor %}
user_{{ name }}_public_key:
  file.managed:
    - name: {{ user.get('home', '/home/{0}'.format(name)) }}/.ssh/id_rsa.pub
    - user: {{ name }}
    - group: {{ name }}
    - mode: 644
    - source: salt://keys/{{ user['privkey'] }}.pub
    - require:
      - user: {{ name }}_user
      {% for group in user.get('groups', []) %}
      - group: {{ group }}_group
      {% endfor %}
  {% endif %}


  {% if 'ssh_auth' in user %}
  {% for auth in user['ssh_auth'] %}
ssh_auth_{{ name }}_{{ loop.index0 }}:
  ssh_auth.present:
    - user: {{ name }}
    - name: {{ auth }}
    - require:
        - file: {{ name }}_user
        - user: {{ name }}_user
{% endfor %}
{% endif %}

{% if 'sudouser' in user %}
sudoer-{{ name }}:
    file.append:
        - name: /etc/sudoers
        - text:
          - "{{ name }}    ALL=(ALL)  NOPASSWD: ALL"
        - require:
          - file: sudoer-defaults

{% endif %}

dotfiles:
  git.latest:
    - name: https://github.com/grengojbo/dotfiles.git
    - target: {{ home }}/dotfiles
    - runas: {{ name }}
    - rev: master
    - force: True
    - force_checkout: True
    - require:
      - file: {{ name }}_user
      - user: {{ name }}_user

{% endfor %}

{% for user in pillar.get('absent_users', []) %}
{{ user }}:
  user.absent
{% endfor %}
