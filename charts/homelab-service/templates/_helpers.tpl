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
Renders a complete tree, even values that contains template.
*/}}
{{- define "service.render" -}}
  {{- if typeIs "string" .value }}
    {{- tpl .value .context }}
  {{ else }}
    {{- tpl (.value | toYaml) .context }}
  {{- end }}
{{- end -}}
