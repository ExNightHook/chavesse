from django.urls import path

from .views import KeyRegisterView

urlpatterns = [
    path('register', KeyRegisterView.as_view(), name='register'),
]
