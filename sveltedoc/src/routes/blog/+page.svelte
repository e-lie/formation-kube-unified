<script>
  export let data;
  const { posts } = data;
</script>

<svelte:head>
  <title>Formation Terraform - Tutoriels</title>
</svelte:head>

<div class="bg-gradient-to-br from-blue-50 to-indigo-100 min-h-screen flex items-center justify-center">
  <div class="text-center max-w-4xl mx-auto px-6">
    <h1 class="text-5xl font-bold mb-6 text-gray-900">Tutoriels Terraform</h1>
    <p class="text-xl text-gray-700 mb-8 leading-relaxed">
      Parcourez les {posts.length} parties de cette formation pour maîtriser Terraform et l'infrastructure as code sur AWS.
    </p>
    
    <div class="bg-white p-8 rounded-lg shadow-md mb-8">
      <h2 class="text-2xl font-semibold mb-4 text-gray-800">Navigation</h2>
      <p class="text-gray-600 mb-4">
        Utilisez le menu de navigation à gauche pour accéder directement à chaque partie de la formation.
      </p>
      <div class="flex justify-center space-x-4">
        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
          📚 Théorie
        </span>
        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
          💻 Pratique
        </span>
        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-purple-100 text-purple-800">
          🏗️ Production
        </span>
      </div>
    </div>
    
    <div class="grid md:grid-cols-2 gap-6">
      <div class="bg-white p-6 rounded-lg shadow-md">
        <h3 class="text-lg font-semibold mb-3 text-blue-600">🚀 Débutant</h3>
        <p class="text-gray-600">Parties 1-3 : Découverte de Terraform, création d'instances EC2 et provisioning</p>
      </div>
      
      <div class="bg-white p-6 rounded-lg shadow-md">
        <h3 class="text-lg font-semibold mb-3 text-yellow-600">⚡ Intermédiaire</h3>
        <p class="text-gray-600">Parties 4-6 : VPC, organisation du code et gestion d'état</p>
      </div>
      
      <div class="bg-white p-6 rounded-lg shadow-md">
        <h3 class="text-lg font-semibold mb-3 text-orange-600">🔥 Avancé</h3>
        <p class="text-gray-600">Parties 7-8 : Backend S3, load balancers et haute disponibilité</p>
      </div>
      
      <div class="bg-white p-6 rounded-lg shadow-md">
        <h3 class="text-lg font-semibold mb-3 text-red-600">🎯 Expert</h3>
        <p class="text-gray-600">Partie 9 : Modules et gestion avancée de l'état</p>
      </div>
    </div>
  </div>
</div>