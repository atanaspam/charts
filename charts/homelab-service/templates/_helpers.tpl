{{/*
Expand the name of the chart.
*/}}
{{- define "service.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create the URL section of the FQDN for the subDomain
*/}}
{{- define "service.url.subDomain" -}}
{{- printf "%s" ( ternary "" (printf ".%s" .Values.subDomain) (empty .Values.subDomain) ) }}
{{- end }}


{{/*
Create the FQDN of the service
*/}}
{{- define "cluster.fqdn" -}}
{{- printf "%s%s.%s" .Values.clusterName (include "service.url.subDomain" . ) .Values.topLevelDomain }}
{{- end }}


{{/*
Common labels
*/}}
{{- define "service.labels" -}}
app: {{ include "service.name" . }}
helm.sh/chart: {{ include "service.chart" . }}
{{ include "service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Homepage annotations
*/}}
{{- define "ingress.homepageAnnotations" -}}
gethomepage.dev/href: {{ printf "https://%s.%s" (include "service.name" .) (include "cluster.fqdn" .) }}
gethomepage.dev/enabled: {{ quote .Values.homepage.enabled }}
{{- if .Values.homepage.group }}
gethomepage.dev/group: {{ .Values.homepage.group }}
{{- end }}
gethomepage.dev/icon: {{ printf "%s.png" (include "service.name" .) }}
gethomepage.dev/name: {{ tpl .Values.homepage.name . }}
#gethomepage.dev/widget.type: { tpl .Values.homepage.widgetType . }
#gethomepage.dev/widget.url: { printf "https://%s.%s" (include "service.name" .) (include "cluster.fqdn" .) }
gethomepage.dev/pod-selector: {{ printf "app.kubernetes.io/name=%s" (include "service.name" .) }}
gethomepage.dev/weight: {{ quote .Values.homepage.weight }}
gethomepage.dev/instance: {{ .Values.clusterName }}
{{- end }}

{{/*
Renders a complete tree, even values that contains template.
*/}}
{{- define "service.render" -}}
  {{- if typeIs "string" .value }}
    {{- tpl .value .context }}
  {{ else }}
    {{- tpl (.value | toYaml) .context }}
  {{- end }}
{{- end -}}
