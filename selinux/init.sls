#!jinja|yaml

{% set selinux  = pillar.get('selinux', {}) -%}

{% if grains['os_family'] == 'RedHat' %}
selinux:
  pkg.installed:
    - pkgs:
      - policycoreutils-python
{%- if grains['osmajorrelease'][0] == '7' %}
      - policycoreutils-devel
{%- endif %}

/etc/selinux/src:
  file.directory:
    - user: root
    - group: root

{% for k, v in salt['pillar.get']('selinux:modules', {}).items() %}
  {% set v_name = v.name|default(k) %}

resetifmissing_{{ k }}:
  cmd:
    - run
    - name: rm -f /etc/selinux/src/{{ v_name }}.te
    - require:
      - pkg: selinux
    - unless: if [ "$(semodule -l | awk '{ print $1 }' | grep {{ v_name }} )" == "{{ v_name }}" ]; then /bin/true; else /bin/false; fi

policy_{{ k }}:
  file:
    - managed
    - name: /etc/selinux/src/{{ v_name }}.te
    - user: root
    - group: root
    - mode: 600
    - contents_pillar: selinux:modules:{{ v_name }}:plain


checkmodule_{{ k }}:
  cmd:
    - wait
    - name: checkmodule -M -m -o {{ v_name }}.mod /etc/selinux/src/{{ v_name }}.te
    - watch:
      - file: /etc/selinux/src/{{ v_name }}.te
    - require:
      - file: /etc/selinux/src/{{ v_name }}.te
      - pkg: selinux
    - unless: if [ "$(semodule -l | awk '{ print $1 }' | grep {{ v_name }} )" == "{{ v_name }}" ]; then /bin/true; else /bin/false; fi

create_package_{{ k }}:
  cmd:
    - wait
    - name: semodule_package -m {{ v_name }}.mod -o {{ v_name }}.pp
    - watch:
      - file: /etc/selinux/src/{{ v_name }}.te
    - require:
      - file: /etc/selinux/src/{{ v_name }}.te
    - unless: if [ "$(semodule -l | awk '{ print $1 }' | grep {{ v_name }} )" == "{{ v_name }}" ]; then /bin/true; else /bin/false; fi

install_semodule_{{ k }}:
  cmd:
    - wait
    - name: semodule -i {{ v_name }}.pp
    - watch:
      - file: /etc/selinux/src/{{ v_name }}.te
    - require:
      - file: /etc/selinux/src/{{ v_name }}.te
    - unless: if [ "$(semodule -l | awk '{ print $1 }' | grep {{ v_name }} )" == "{{ v_name }}" ]; then /bin/true; else /bin/false; fi

{% endfor %}

selinux-config:
  file:
    - managed
    - name: /etc/selinux/config
    - user: root
    - group: root
    - mode: 600
    - source: salt://selinux/files/config
    - template: jinja

selinux-state:
    cmd.run:
        - name: setenforce {{ selinux.state|default('enforcing') }}
        - unless: if [ "$(sestatus | awk '/Current mode/ { print $3 }')" = {{ selinux.state|default('enforcing') }} ]; then /bin/true; else /bin/false; fi


{% endif %}
