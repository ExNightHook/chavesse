from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

SCHEMA_URL_NAME = 'schema'

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('rest_framework.urls')),
    path('schema/', SpectacularAPIView.as_view(), name=SCHEMA_URL_NAME),
    path('docs/', SpectacularSwaggerView.as_view(url_name=SCHEMA_URL_NAME)),

    path('api/', include('keys.urls')),
]
